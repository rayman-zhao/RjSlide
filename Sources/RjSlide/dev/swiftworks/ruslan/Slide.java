package dev.swiftworks.ruslan;

public class Slide implements AutoCloseable {
    static {
        System.loadLibrary("RjSlide");
    }

    private String path;
    private boolean valid;

    public Slide(String path) {
        this.path = path;
        this.valid = create(path);
    }

    @Override
    public void close() {
        if (valid) release(path);
    }

    private native boolean create(String path);
    private native void release(String path);

    public static void main(String[] args) {
        try (Slide s = new Slide(args[0])) {
            System.out.println("Open " + s.path + " " + s.valid);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}