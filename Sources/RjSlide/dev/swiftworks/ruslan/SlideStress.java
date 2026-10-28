package dev.swiftworks.ruslan;

import java.util.ArrayList;

// Multi-threaded stress test for the Slide JNI surface. Every native call is
// serialized behind the instance monitor, so the invariants under fire are:
// a shared slide never crashes nor returns a torn JPEG/DTO payload, a close
// racing readers may only flip results from full to empty, and independent
// slides hammered in parallel must not corrupt each other's native state.
public class SlideStress {

    private static final int MACRO_CALLS = 30;
    private static final int LABEL_CALLS = 30;
    private static final int TILE_CALLS = 240;
    private static final int THUMBNAIL_CALLS = 15;
    private static final int DTO_CALLS = 240;

    private static final int CLOSE_ROUNDS = 24;
    private static final int CLOSE_READERS = 4;

    private static final int OWNER_THREADS = 8;
    private static final int SLIDES_PER_OWNER = 15;

    private static final ArrayList<String> failures = new ArrayList<String>();
    private static long totalOps;

    public static void main(String[] args) throws Exception {
        String path = args[0];

        sharedInstanceReads(path);
        System.out.println("shared-instance reads: " + ops() + " ops");

        closeRace(path);
        System.out.println("close race: " + ops() + " ops");

        independentSlides(path);
        System.out.println("independent slides: " + ops() + " ops");

        if (!failures.isEmpty()) {
            for (int i = 0; i < failures.size(); i++) {
                System.out.println("FAIL: " + failures.get(i));
            }
            throw new AssertionError(failures.size() + " stress failure(s)");
        }
        System.out.println("Stress OK");
    }

    // Phase 1: one Slide, specialist workers interleaving every read path
    // through the shared monitor.
    private static void sharedInstanceReads(String path) throws InterruptedException {
        Slide slide = new Slide(path);
        check(slide.nativeSlide != 0, "slide open failed");

        runAll(
            new Thread[] {
                new Worker(slide, "macro", MACRO_CALLS),
                new Worker(slide, "label", LABEL_CALLS),
                new Worker(slide, "tile", TILE_CALLS),
                new Worker(slide, "thumbnail", THUMBNAIL_CALLS),
                new Worker(slide, "dto", DTO_CALLS),
            });
        slide.close();
    }

    // Phase 2: readers loop on a fresh slide while the main thread closes it.
    // A read must see either a full payload (close not yet effective) or an
    // empty one (close happened); anything else is a torn state. Reader loops
    // end on their own once nativeSlide reads 0, which stays visible because
    // every getter and close() share the instance monitor.
    private static void closeRace(String path) throws InterruptedException {
        for (int round = 0; round < CLOSE_ROUNDS; round++) {
            Slide slide = new Slide(path);
            check(slide.nativeSlide != 0, "slide open failed");

            RaceReader[] readers = new RaceReader[CLOSE_READERS];
            for (int i = 0; i < readers.length; i++) {
                readers[i] = new RaceReader(slide, round + i);
                readers[i].start();
            }

            Thread.sleep(round % 3);
            slide.close();

            for (int i = 0; i < readers.length; i++) {
                readers[i].join();
            }

            check(slide.nativeSlide == 0, "native pointer must be cleared after close");
            check(
                slide.getMacro().length == 0 && slide.getTile("f", 0, 0, 0, 0, 0).length == 0,
                "reads after close must be empty");
        }
    }

    // Phase 3: owners open, read and release their own slides concurrently,
    // orphaning some for the cleaner so release() races live native calls on
    // other instances; the GC churn from the main thread keeps the cleaner
    // fed while the owners work.
    private static void independentSlides(String path) throws InterruptedException {
        Owner[] owners = new Owner[OWNER_THREADS];
        for (int i = 0; i < owners.length; i++) {
            owners[i] = new Owner(path);
            owners[i].start();
        }

        while (anyAlive(owners)) {
            System.gc();
            Thread.sleep(250);
        }
        for (int i = 0; i < owners.length; i++) {
            owners[i].join();
        }
    }

    // Specialist reader hammering one native operation on a shared slide.
    static final class Worker extends Thread {
        private final Slide slide;
        private final String op;
        private final int calls;

        Worker(Slide slide, String op, int calls) {
            super("stress-" + op);
            this.slide = slide;
            this.op = op;
            this.calls = calls;
        }

        @Override
        public void run() {
            try {
                for (int i = 0; i < calls; i++) {
                    if (op.equals("macro")) {
                        checkImage(slide.getMacro(), "macro");
                    } else if (op.equals("label")) {
                        checkImage(slide.getLabel(), "label");
                    } else if (op.equals("tile")) {
                        // sweep coords may be out of range and legitimately
                        // decode to empty; the origin tile may not
                        checkImageOrEmpty(slide.getTile("f", 0, 0, i % 3, i % 4, 0), "tile");
                        checkImage(slide.getTile("f", 0, 0, 0, 0, 0), "tile");
                    } else if (op.equals("thumbnail")) {
                        checkImage(slide.getThumbnail(64), "thumbnail");
                    } else {
                        checkDto(slide.getUploadSlideDTO());
                    }
                    countOp();
                }
            } catch (Throwable t) {
                fail(op + " threw " + t);
            }
        }
    }

    // Spinning reader for the close race; alternates the cheap and the heavy
    // read so the close can land mid-decode as well as between calls.
    static final class RaceReader extends Thread {
        private final Slide slide;
        private final int seed;

        RaceReader(Slide slide, int seed) {
            super("stress-close-reader");
            this.slide = slide;
            this.seed = seed;
        }

        @Override
        public void run() {
            try {
                int i = seed;
                while (slide.nativeSlide != 0) {
                    byte[] payload;
                    String what;
                    if ((i & 1) == 0) {
                        payload = slide.getTile("f", 0, 0, 0, 0, 0);
                        what = "tile";
                    } else {
                        payload = slide.getMacro();
                        what = "macro";
                    }
                    if (payload.length > 0) {
                        checkImage(payload, what);
                    } else if (slide.nativeSlide != 0) {
                        fail(what + " came back empty while the slide was still open");
                    }
                    countOp();
                    i++;
                }
            } catch (Throwable t) {
                fail("close-race reader threw " + t);
            }
        }
    }

    // Owns a batch of slides; every fourth one is abandoned for the cleaner
    // instead of being closed explicitly.
    static final class Owner extends Thread {
        private final String path;

        Owner(String path) {
            super("stress-owner");
            this.path = path;
        }

        @Override
        public void run() {
            try {
                for (int i = 0; i < SLIDES_PER_OWNER; i++) {
                    Slide slide = new Slide(path);
                    if (slide.nativeSlide == 0) {
                        fail("slide open failed");
                        return;
                    }
                    try {
                        // alternate label-first/macro-first so the forced macro
                        // rotation is initialized from both call paths
                        if ((i & 1) == 0) {
                            checkImage(slide.getLabel(), "label");
                        } else {
                            checkImage(slide.getMacro(), "macro");
                        }
                        checkImage(slide.getTile("f", 0, 0, 0, 0, 0), "tile");
                        checkImage(slide.getThumbnail(64), "thumbnail");
                        checkDto(slide.getUploadSlideDTO());
                        countOp();
                    } finally {
                        if ((i % 4) != 3) {
                            slide.close();
                        }
                    }
                }
            } catch (Throwable t) {
                fail("owner threw " + t);
            }
        }
    }

    private static boolean anyAlive(Thread[] threads) {
        for (int i = 0; i < threads.length; i++) {
            if (threads[i].isAlive()) {
                return true;
            }
        }
        return false;
    }

    private static void runAll(Thread[] threads) throws InterruptedException {
        for (int i = 0; i < threads.length; i++) {
            threads[i].start();
        }
        for (int i = 0; i < threads.length; i++) {
            threads[i].join();
        }
    }

    // All image getters return JPEG bytes, so a torn buffer shows up as a
    // missing SOI marker rather than just a suspicious length.
    private static void checkImage(byte[] jpeg, String what) {
        if (jpeg.length < 2 || (jpeg[0] & 0xFF) != 0xFF || (jpeg[1] & 0xFF) != 0xD8) {
            fail(what + " is not a JPEG payload (" + jpeg.length + " bytes)");
        }
    }

    private static void checkImageOrEmpty(byte[] jpeg, String what) {
        if (jpeg.length > 0) {
            checkImage(jpeg, what);
        }
    }

    private static void checkDto(String dto) {
        if (!dto.contains("\"manufacturer\"") || !dto.contains("\"layers\"")) {
            fail("upload slide DTO incomplete");
        }
    }

    private static synchronized void countOp() {
        totalOps++;
    }

    private static synchronized long ops() {
        return totalOps;
    }

    private static synchronized void fail(String message) {
        failures.add(Thread.currentThread().getName() + ": " + message);
    }

    private static void check(boolean ok, String message) {
        if (!ok) {
            throw new AssertionError(message);
        }
    }
}
