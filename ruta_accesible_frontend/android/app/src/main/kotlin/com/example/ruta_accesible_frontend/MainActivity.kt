import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rutaaccesible/tts"
    private lateinit var tts: TextToSpeech

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts.language = Locale("es", "MX")   // Voz nativa español México
                tts.setSpeechRate(0.85f)             // Velocidad cómoda adultos mayores
                tts.setPitch(1.0f)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hablar" -> {
                        val texto = call.argument<String>("texto") ?: ""
                        tts.speak(texto, TextToSpeech.QUEUE_FLUSH, null, null)
                        result.success(null)
                    }
                    "detener" -> {
                        tts.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        tts.stop()
        tts.shutdown()
        super.onDestroy()
    }
}