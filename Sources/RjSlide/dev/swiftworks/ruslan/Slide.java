package dev.swiftworks.ruslan;

import java.nio.file.*;

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

    public byte[] getMacro() {
        return valid ? macro(path) : null;
    }

    public byte[] getLabel() {
        return valid ? label(path) : null;
    }

    private native boolean create(String path);
    private native void release(String path);
    private native byte[] macro(String path);
    private native byte[] label(String path);

    public static void main(String[] args) {
        try (Slide s = new Slide(args[0])) {
            System.out.println("Open " + s.path + " " + s.valid);

            byte[] macro = s.getMacro();
            System.out.println("Got macro image in " + macro.length);
            Files.write(Paths.get("macro.jpg"), macro);

            byte[] label = s.getLabel();
            System.out.println("Got label image in " + label.length);
            Files.write(Paths.get("label.jpg"), label);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}