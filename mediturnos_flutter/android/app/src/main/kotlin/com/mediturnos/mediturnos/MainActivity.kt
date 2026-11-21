package com.mediturnos.mediturnos

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mediturnos.mediturnos/calendario")
            .setMethodCallHandler { call, result ->
                if (call.method != "crearEvento") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val zona = call.argument<String>("zona")
                val titulo = call.argument<String>("titulo")
                val fechaHora = call.argument<String>("fechaHora")
                val duracion = call.argument<Number>("duracionMs")?.toLong()
                if (zona == null || titulo == null || fechaHora == null || duracion == null || duracion <= 0) {
                    result.error("TURNO_INVALIDO", "Faltan datos del turno.", null)
                    return@setMethodCallHandler
                }
                val formato = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.ROOT).apply {
                    timeZone = TimeZone.getTimeZone(zona)
                    isLenient = false
                }
                val inicio = try {
                    formato.parse(fechaHora)!!.time
                } catch (_: java.text.ParseException) {
                    result.error("FECHA_INVALIDA", "Fecha del turno inválida.", null)
                    return@setMethodCallHandler
                }
                val evento = Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI).apply {
                    putExtra(CalendarContract.Events.TITLE, titulo)
                    putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, inicio)
                    putExtra(CalendarContract.EXTRA_EVENT_END_TIME, inicio + duracion)
                    putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, false)
                    putExtra(CalendarContract.Events.EVENT_TIMEZONE, zona)
                    putExtra(CalendarContract.Events.EVENT_END_TIMEZONE, zona)
                }
                result.success(abrirEvento(Intent(evento).setPackage("com.google.android.calendar")) || abrirEvento(evento))
            }
    }

    private fun abrirEvento(evento: Intent): Boolean = try {
        startActivity(evento)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }
}
