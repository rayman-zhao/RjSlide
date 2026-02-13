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

    public static void main(String[] args) {
        try (Register r = new Register()) {
            System.out.println(r.runPixelsRGB24(new byte[300], 10, 10, new byte[300], 10, 10));
            System.out.println(r.runPaths(args[0], args[1], args[2]));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}