import de.tum.cit.ase.PhobosAccess;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;


class PhobosAccessTest {

    private static PhobosAccess phobos;

    @BeforeAll
    static void init() {
        phobos = new PhobosAccess();
    }

    @Test
    void writeToCoreMustFail() {
        boolean ok = phobos.attemptWrite("/opt/core/notauthorised.txt", "forbidden");
        assertFalse(ok, "Write into /opt/core should remain blocked");
    }

    @Test
    void connectToGoogleMustFail() {
        boolean ok = phobos.attemptConnection("https://www.google.com");
        assertFalse(ok, "Outbound connection to Google should remain blocked");
    }

    @Test
    void writeToTestReposMustSucceed() {
        boolean ok = phobos.attemptWrite("/tmp", "allowed");
        assertTrue(ok, "Write into /tmp should succeed");
    }

    @Test
    void connectToArtemisMustSucceed() {
        boolean ok = phobos.attemptConnection("https://artemis-test2.artemis.cit.tum.de/");
        assertTrue(ok, "Connection to the internal Artemis instance should succeed");
    }

    @Test
    void lsMustFail() {
        assertFalse(phobos.tryExec("/bin/ls"),
                "'ls' should be blocked inside the sandbox");
    }

    @Test
    void echoMustSucceed() {
        assertTrue(phobos.tryExec("/bin/echo", "hello"),
                "'echo' should still work");
    }

    @Test
    void attemptCreateDirectoryMustFail() {
        boolean ok = phobos.tryExec("mkdir", "/opt/core/unaouthorised_dir");
        assertFalse(ok, "Creating a directory should not be allowed");
    }
}
