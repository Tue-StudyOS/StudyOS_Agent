package com.studyos.studyos_agent

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

class AndroidLocalModelStore(context: Context) {
    private val appContext = context.applicationContext
    private val modelDir = File(appContext.filesDir, "local_models")
    private val metadataFile = File(modelDir, "models.json")
    @Volatile private var cancelRequested = false
    @Volatile private var activeConnection: HttpURLConnection? = null

    init {
        if (!modelDir.exists()) {
            modelDir.mkdirs()
        }
    }

    fun listModels(): List<Map<String, Any?>> {
        val metadata = readMetadata()
        return metadata.keys().asSequence().mapNotNull { id ->
            val item = metadata.optJSONObject(id) ?: return@mapNotNull null
            val file = File(modelDir, item.optString("fileName"))
            itemToMap(id, item, file)
        }.toList()
    }

    fun downloadModel(
        id: String,
        label: String,
        fileName: String,
        url: String,
        expectedSizeBytes: Long = -1L,
        expectedSha256: String = "",
        onProgress: (Long, Long) -> Unit = { _, _ -> },
    ): Map<String, Any?> {
        require(id.isNotBlank()) { "Model id is required." }
        require(label.isNotBlank()) { "Model label is required." }
        require(url.startsWith("https://")) { "Model URL must use HTTPS." }
        val safeFileName = sanitizeFileName(fileName)
        require(safeFileName.endsWith(".litertlm") || safeFileName.endsWith(".task")) {
            "Only .litertlm and .task model files are supported."
        }

        val target = File(modelDir, safeFileName)
        val partial = File(modelDir, "$safeFileName.download")
        cancelRequested = false
        val verified = downloadToFile(
            url = url,
            target = partial,
            expectedSizeBytes = expectedSizeBytes,
            expectedSha256 = expectedSha256,
            onProgress = onProgress,
        )
        if (target.exists()) {
            target.delete()
        }
        check(partial.renameTo(target)) { "Could not move downloaded model into place." }

        val metadata = readMetadata()
        metadata.put(
            id,
            JSONObject()
                .put("label", label)
                .put("fileName", safeFileName)
                .put("url", url)
                .put("sizeBytes", verified.sizeBytes)
                .put("sha256", verified.sha256)
                .put("expectedSizeBytes", expectedSizeBytes.takeIf { it > 0 })
                .put("expectedSha256", expectedSha256.ifBlank { null })
                .put("downloadedAt", System.currentTimeMillis()),
        )
        writeMetadata(metadata)
        return itemToMap(id, metadata.getJSONObject(id), target)
    }

    fun cancelDownload() {
        cancelRequested = true
        activeConnection?.disconnect()
    }

    fun deleteModel(id: String): Boolean {
        val metadata = readMetadata()
        val item = metadata.optJSONObject(id) ?: return false
        val file = File(modelDir, item.optString("fileName"))
        val deleted = !file.exists() || file.delete()
        metadata.remove(id)
        writeMetadata(metadata)
        return deleted
    }

    private fun itemToMap(
        id: String,
        item: JSONObject,
        file: File,
    ): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "label" to item.optString("label"),
            "fileName" to item.optString("fileName"),
            "path" to file.absolutePath,
            "url" to item.optString("url"),
            "downloadedAt" to item.optLong("downloadedAt"),
            "exists" to file.exists(),
            "sizeBytes" to if (file.exists()) file.length() else 0L,
            "sha256" to item.optString("sha256"),
            "expectedSizeBytes" to item.optLong("expectedSizeBytes").takeIf { it > 0 },
            "expectedSha256" to item.optString("expectedSha256").takeIf { it.isNotBlank() },
        )
    }

    private fun downloadToFile(
        url: String,
        target: File,
        expectedSizeBytes: Long,
        expectedSha256: String,
        onProgress: (Long, Long) -> Unit,
    ): DownloadVerification {
        if (target.exists()) {
            target.delete()
        }
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 60_000
        connection.instanceFollowRedirects = true
        activeConnection = connection
        connection.connect()
        try {
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("Download failed with HTTP ${connection.responseCode}.")
            }
            val totalBytes = connection.contentLengthLong.takeIf { it > 0 } ?: -1L
            if (expectedSizeBytes > 0 && totalBytes > 0 && totalBytes != expectedSizeBytes) {
                throw IllegalStateException(
                    "Download size mismatch before transfer: expected " +
                        "$expectedSizeBytes bytes, got $totalBytes.",
                )
            }
            var receivedBytes = 0L
            val digest = MessageDigest.getInstance("SHA-256")
            try {
                connection.inputStream.use { input ->
                    target.outputStream().use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            if (cancelRequested) {
                                target.delete()
                                throw InterruptedException("Download cancelled.")
                            }
                            val read = input.read(buffer)
                            if (read < 0) break
                            output.write(buffer, 0, read)
                            digest.update(buffer, 0, read)
                            receivedBytes += read
                            onProgress(receivedBytes, totalBytes)
                        }
                    }
                }
            } catch (error: Exception) {
                target.delete()
                if (cancelRequested) {
                    throw InterruptedException("Download cancelled.")
                }
                throw error
            }
            if (expectedSizeBytes > 0 && receivedBytes != expectedSizeBytes) {
                target.delete()
                throw IllegalStateException(
                    "Download size mismatch: expected $expectedSizeBytes " +
                        "bytes, got $receivedBytes.",
                )
            }
            val sha256 = digest.digest().joinToString("") {
                "%02x".format(it.toInt() and 0xff)
            }
            if (expectedSha256.isNotBlank() && !sha256.equals(expectedSha256, ignoreCase = true)) {
                target.delete()
                throw IllegalStateException("Download checksum mismatch.")
            }
            return DownloadVerification(receivedBytes, sha256)
        } finally {
            activeConnection = null
            connection.disconnect()
        }
    }

    private fun readMetadata(): JSONObject {
        if (!metadataFile.exists()) {
            return JSONObject()
        }
        return runCatching {
            JSONObject(metadataFile.readText())
        }.getOrElse { JSONObject() }
    }

    private fun writeMetadata(metadata: JSONObject) {
        val keys = metadata.keys().asSequence().toList().sorted()
        val ordered = JSONObject()
        keys.forEach { key ->
            ordered.put(key, metadata.get(key))
        }
        metadataFile.writeText(ordered.toString(2))
    }

    private fun sanitizeFileName(value: String): String {
        val cleaned = value.trim().replace(Regex("[^A-Za-z0-9._-]"), "-")
        return cleaned.ifBlank { "local-model.task" }
    }

    private data class DownloadVerification(
        val sizeBytes: Long,
        val sha256: String,
    )
}
