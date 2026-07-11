import java.lang.instrument.Instrumentation;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class EphemeraNodeAgent {

    private static final String COLLECTOR_URL = System.getProperty("ephemera.collector.url", "http://localhost:8080/ingest");
    private static final String SERVICE_NAME = System.getProperty("ephemera.service.name", "jvm-service");
    private static final ExecutorService dispatcher = Executors.newFixedThreadPool(2);

    public static void premain(String agentArgs, Instrumentation inst) {
        System.out.println("[EphemeraNode] Initializing JVM Instrumentation Agent...");
        
        inst.addTransformer(new ExceptionTransformer());
        
        Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
            broadcastException(e, "UncaughtThreadException");
        });
    }

    private static void broadcastException(Throwable throwable, String type) {
        dispatcher.submit(() -> {
            HttpURLConnection connection = null;
            try {
                URL url = new URL(COLLECTOR_URL);
                connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("POST");
                connection.setDoOutput(true);
                connection.setRequestProperty("Content-Type", "application/json");

                String stackTrace = "";
                if (throwable.getStackTrace().length > 0) {
                    stackTrace = throwable.getStackTrace()[0].toString();
                }

                String payload = String.format(
                    "{\"service\":\"%s\",\"type\":\"%s\",\"message\":\"%s\",\"trace\":\"%s\",\"timestamp\":%d}",
                    SERVICE_NAME,
                    type,
                    throwable.toString().replace("\"", "\\\""),
                    stackTrace.replace("\"", "\\\""),
                    System.currentTimeMillis()
                );

                try (OutputStream os = connection.getOutputStream()) {
                    byte[] input = payload.getBytes(StandardCharsets.UTF_8);
                    os.write(input, 0, input.length);
                }

                int code = connection.getResponseCode();
                if (code >= 400) {
                    // Fail silently to avoid recursion or logging loops in target app
                }
            } catch (Exception ignored) {
            } finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
        });
    }

    /**
     * Minimalist transformer to intercept core exception constructors.
     * In a production environment, this would utilize ASM or ByteBuddy to 
     * inject bytecode into java.lang.Throwable, but for a standalone agent 
     * without external dependencies, we hook into the runtime's default handlers.
     */
    static class ExceptionTransformer implements ClassFileTransformer {
        @Override
        public byte[] transform(ClassLoader loader, String className, Class<?> classBeingRedefined,
                                ProtectionDomain protectionDomain, byte[] classfileBuffer) {
            // This agent primarily relies on the UncaughtExceptionHandler and 
            // explicit library hooks. Bytecode manipulation of java.lang.Throwable 
            // requires specific JVM flags (-Xbootclasspath) which is handled 
            // at the launcher level for EphemeraNode.
            return null;
        }
    }

    // Direct API for manual instrumentation within polyglot microservices
    public static void report(Throwable t) {
        broadcastException(t, "HandledException");
    }
}