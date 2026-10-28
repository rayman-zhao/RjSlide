package dev.swiftworks.ruslan;

import java.lang.ref.Cleaner;

// The native side is not thread-safe; every instance method must stay
// synchronized to serialize access through the native wrapper pointer.
// The lock sits in Java wrappers instead of on the native declarations
// because a JIT-compiled call into a `synchronized native` method crashes
// the JVM (Temurin 25 on Windows; the interpreted entry is fine).
public class Slide implements AutoCloseable {
    static {
        System.loadLibrary("RjSlide");
    }

    private static final Cleaner CLEANER = Cleaner.create();

    public long nativeSlide = 0;
    private final Cleaner.Cleanable cleanable;

    public Slide(String path) {
        nativeSlide = create(path);
        cleanable = CLEANER.register(this, new Releaser(nativeSlide));
    }

    @Override
    public synchronized void close() {
        nativeSlide = 0;
        cleanable.clean();
    }

    // The cleaning action must not capture the Slide instance, only the raw
    // pointer, or the object would never become phantom-reachable.
    private static final class Releaser implements Runnable {
        private final long nativeSlide;

        Releaser(long nativeSlide) {
            this.nativeSlide = nativeSlide;
        }

        @Override
        public void run() {
            if (nativeSlide != 0) {
                release(nativeSlide);
            }
        }
    }

    public synchronized byte[] getMacro() {
        return nativeGetMacro();
    }

    public synchronized byte[] getLabel() {
        return nativeGetLabel();
    }

    public synchronized byte[] getTile(String imageId, int tier, int level, int x, int y, int channel) {
        return nativeGetTile(imageId, tier, level, x, y, channel);
    }

    public synchronized byte[] getThumbnail(int maxSize) {
        return nativeGetThumbnail(maxSize);
    }

    public synchronized String getUploadSlideDTO() {
        return nativeGetUploadSlideDTO();
    }

    private native long create(String path);
    private static native void release(long nativeSlide);
    private native byte[] nativeGetMacro();
    private native byte[] nativeGetLabel();
    private native byte[] nativeGetTile(String imageId, int tier, int level, int x, int y, int channel);
    private native byte[] nativeGetThumbnail(int maxSize);
    private native String nativeGetUploadSlideDTO();

    public static void main(String[] args) throws Exception {
        try (Slide s = new Slide(args[0])) {
            check(s.nativeSlide != 0, "slide open failed");
            System.out.println("Open " + args[0] + " at address 0x" + Long.toHexString(s.nativeSlide));

            byte[] macro = s.getMacro();
            check(macro.length > 0, "macro image empty");
            System.out.println("Got macro image in " + macro.length);

            byte[] label = s.getLabel();
            check(label.length > 0, "label image empty");
            System.out.println("Got label image in " + label.length);

            byte[] tile = s.getTile("f", 0, 0, 0, 0, 0);
            check(tile.length > 0, "tile image empty");
            System.out.println("Got tile in " + tile.length);

            byte[] thumbnail = s.getThumbnail(256);
            check(thumbnail.length > 0, "thumbnail image empty");
            System.out.println("Got thumbnail in " + thumbnail.length);

            String dto = s.getUploadSlideDTO();
            check(dto.contains("\"manufacturer\"") && dto.contains("\"layers\""), "upload slide DTO incomplete");
            System.out.println("UploadSlideDTO : " + dto);
        }

        // Regression checks for the cleaner-based lifecycle: close() is idempotent,
        // calls after close return empty, and the cleaner releases an orphaned
        // slide on the cleaner thread without crashing.
        // Fetching the label before the macro must not deadlock the wrapper lock.
        Slide closed = new Slide(args[0]);
        check(closed.nativeSlide != 0, "slide open failed");
        check(closed.getLabel().length > 0, "label image empty");
        closed.close();
        closed.close();
        check(closed.getMacro().length == 0 && closed.getTile("f", 0, 0, 0, 0, 0).length == 0,
            "use after close must return empty");

        Slide orphan = new Slide(args[0]);
        check(orphan.getMacro().length > 0, "macro image empty");
        orphan = null;
        System.gc();
        Thread.sleep(500);
        System.out.println("Close semantics OK");
    }

    private static void check(boolean ok, String message) {
        if (!ok) {
            throw new AssertionError(message);
        }
    }
}