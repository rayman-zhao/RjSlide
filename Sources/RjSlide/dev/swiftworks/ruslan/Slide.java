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
        if (!valid) return null;

        byte[] img = macro(path);
        return img.length > 0 ? img : null;
    }

    public byte[] getLabel() {
       if (!valid) return null;
       
       byte[] img = label(path);
       return img.length > 0 ? img : null;
    }

    public byte[] getTile(String imageId, int tier, int level, int x, int y) {
        if (!valid) return null;
        
        byte[] img = tile(path, tier, level, x, y);
        return img.length > 0 ? img : null;
    }

    private native boolean create(String path);
    private native void release(String path);
    private native byte[] macro(String path);
    private native byte[] label(String path);
    private native byte[] tile(String path, int tier, int level, int x, int y);

    public static void main(String[] args) {
        try (Slide s = new Slide(args[0])) {
            System.out.println("Open " + s.path + " " + s.valid);

            byte[] macro = s.getMacro();
            System.out.println("Got macro image in " + macro.length);
            Files.write(Paths.get("macro.jpg"), macro);

            byte[] label = s.getLabel();
            System.out.println("Got label image in " + label.length);
            Files.write(Paths.get("label.jpg"), label);

            byte[] tile = s.getTile("f", 0, 3, 0, 0);
            System.out.println("Got tile in " + tile.length);
            Files.write(Paths.get("tile.jpg"), tile);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}