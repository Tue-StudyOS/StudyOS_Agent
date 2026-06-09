package com.example.studyOS.Sensors;

import android.content.Context;
import android.location.Geocoder;
import com.example.studyOS.DataStructures.GPS;

import java.util.Locale;

public class GeoCodeManager {

    private final Context context;
    private final Geocoder geocoder;

    public GeoCodeManager(Context context) {
        this.context = context;
        this.geocoder = new Geocoder(context, Locale.getDefault());
    }

    public String getAddress(GPS location) {
        var geocoder = new Geocoder(context, Locale.getDefault());

        try {
            var addresses = geocoder.getFromLocation(location.lat(), location.lon(), 1);
            if (addresses == null || addresses.isEmpty())
                return "Unknown Location";

            var addr = addresses.get(0);
            var sb = new StringBuilder();


            if (addr.getAddressLine(0) != null)
                sb.append(addr.getAddressLine(0));
            else {
                if (addr.getFeatureName() != null)
                    sb.append(addr.getFeatureName());

                if (addr.getThoroughfare() != null)
                    sb.append(", ").append(addr.getThoroughfare());

                if (addr.getSubThoroughfare() != null)
                    sb.append(" ").append(addr.getSubThoroughfare());

                if (addr.getSubLocality() != null)
                    sb.append(", ").append(addr.getSubLocality());

                if (addr.getLocality() != null)
                    sb.append(", ").append(addr.getLocality());

                if (addr.getAdminArea() != null)
                    sb.append(", ").append(addr.getAdminArea());

                if (addr.getCountryName() != null)
                    sb.append(", ").append(addr.getCountryName());
            }

            var result = sb.toString().trim();
            if (result.startsWith(","))
                result = result.substring(1).trim();

            if (result.isEmpty())
                return "Unknown Location";

            System.out.println("GEO_CODED: " + result);
            return result;
        } catch (Exception e) {
            System.err.println("Geocoding error: " + e.getMessage());
            return "Geocoding Error";
        }
    }
}