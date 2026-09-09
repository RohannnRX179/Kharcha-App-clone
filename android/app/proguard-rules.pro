# flutter_local_notifications schedules/restores notifications via a
# reflection-based Gson round-trip of its own model classes — R8 must not
# rename or strip them, or a scheduled alarm silently fails to restore
# after a device reboot.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
