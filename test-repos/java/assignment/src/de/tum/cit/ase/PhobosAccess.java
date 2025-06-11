package de.tum.cit.ase;

import java.util.concurrent.TimeUnit;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;

public class PhobosAccess {

    /**
     * Attempts to write the given content to the supplied absolute path.
     * If the path points to a directory, the method drops a new timestamped file inside it.
     *
     * @return true when the write succeeds, false on IOException / SecurityException.
     */
    public boolean attemptWrite(String absolutePath, String content) {
        Path target = Paths.get(absolutePath);
        try {
            // If caller passed a directory, create a file inside it.
            if (Files.isDirectory(target)) {
                target = target.resolve("phobos_access_" + System.currentTimeMillis() + ".txt");
            }
            Files.createDirectories(target.getParent());
            Files.write(
                    target,
                    content.getBytes(StandardCharsets.UTF_8),
                    StandardOpenOption.CREATE,
                    StandardOpenOption.TRUNCATE_EXISTING
            );
            return true;
        } catch (IOException | SecurityException ex) {
            System.err.println("Write failed: " + ex.getMessage());
            return false;
        }
    }

    /**
     * Attempts an HTTP HEAD request to the supplied URL.
     *
     * @return true when the remote host returns a 2xx–3xx status, false on any exception.
     */
    public boolean attemptConnection(String url) {
        try {
            HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
            conn.setRequestMethod("HEAD");
            conn.setConnectTimeout(3_000);
            conn.setReadTimeout(3_000);
            int code = conn.getResponseCode();
            return code >= 200 && code < 400;
        } catch (IOException | SecurityException ex) {
            System.err.println("Connection denied: " + ex.getMessage());
            return false;
        }
    }

    /**
     * Try to run a shell command; return true only when it exits 0.
     */
    public boolean tryExec(String... cmd) {
        ProcessBuilder pb = new ProcessBuilder(cmd)
                .redirectErrorStream(true);
        try {
            Process p = pb.start();
            if (!p.waitFor(3, TimeUnit.SECONDS)) {
                p.destroyForcibly();
                return false;
            }
            return p.exitValue() == 0;
        } catch (IOException | InterruptedException ex) {
            return false;
        }
    }
}
