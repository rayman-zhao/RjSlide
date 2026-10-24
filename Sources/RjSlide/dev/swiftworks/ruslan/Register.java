package dev.swiftworks.ruslan;

public class Register implements AutoCloseable {
    static {
        System.loadLibrary("RjSlide");
    }

    public Register() {
    }

    @Override
    public void close() {
    }

    public native String runPixelsRGB24(byte[] rgb, int w, int h, byte[] rgb2, int w2, int h2);
    private native String runPaths(String fn, String fn2, String output);

    public static void main(String[] args) throws Exception {
        try (Register r = new Register()) {
            String pixels = r.runPixelsRGB24(new byte[300], 10, 10, new byte[300], 10, 10);
            check(pixels != null && pixels.contains("\"result\""), "runPixelsRGB24 result malformed");
            System.out.println(pixels);

            String paths = r.runPaths(args[0], args[1], args[2]);
            check(paths != null && paths.contains("\"result\""), "runPaths result malformed");
            System.out.println(paths);
        }
    }

    private static void check(boolean ok, String message) {
        if (!ok) {
            throw new AssertionError(message);
        }
    }
}