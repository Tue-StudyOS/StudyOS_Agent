package com.studyos.studyos_agent

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal class AndroidPdfPreview(private val context: Context) {
    fun open(call: MethodCall, result: MethodChannel.Result) {
        val document = call.argument<ByteArray>("document")
        val filename = call.argument<String>("filename")
        if (document == null || filename.isNullOrBlank()) {
            result.error(
                "pdf_preview_arguments",
                "Expected an ALMA PDF document and filename.",
                null,
            )
            return
        }
        if (!document.isPdf()) {
            result.error(
                "pdf_preview_invalid_document",
                "ALMA did not return a valid PDF document.",
                null,
            )
            return
        }

        try {
            val directory = File(context.cacheDir, "pdf_previews").apply { mkdirs() }
            val file = File(directory, filename.safePdfFilename()).apply {
                writeBytes(document)
            }
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
            context.startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/pdf")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                },
            )
            result.success("ALMA PDF opened.")
        } catch (_: ActivityNotFoundException) {
            result.error(
                "pdf_viewer_unavailable",
                "No app capable of opening PDF documents is installed.",
                null,
            )
        } catch (error: Exception) {
            result.error(
                "pdf_preview_failed",
                "StudyOS could not open the ALMA PDF: ${error.message}",
                null,
            )
        }
    }

    private fun ByteArray.isPdf(): Boolean =
        size >= PDF_SIGNATURE.size &&
            PDF_SIGNATURE.indices.all { index -> this[index] == PDF_SIGNATURE[index] }

    private fun String.safePdfFilename(): String {
        val stem = substringBeforeLast('.').replace(unsafeFilenameCharacters, "-")
            .trim('-')
            .ifBlank { "alma-document" }
        return "$stem.pdf"
    }

    private companion object {
        val PDF_SIGNATURE = "%PDF-".encodeToByteArray()
        val unsafeFilenameCharacters = Regex("[^A-Za-z0-9._-]+")
    }
}
