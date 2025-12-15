package dev.swiftworks.ruslan;

import java.nio.file.*;

public class Slide implements AutoCloseable {
    static {
        System.loadLibrary("RjSlide");
    }

    public long pointer = 0;

    public Slide(String path) {
        pointer = create(path);
    }

    @Override
    public void close() {
        release();
    }

    private native long create(String path);
    private native void release();
    private native byte[] getMacro();
    private native byte[] getLabel();
    private native byte[] getTile(String imageId, int tier, int level, int x, int y);

    public static void main(String[] args) {
        try (Slide s = new Slide(args[0])) {
            System.out.print("Open " + args[0] + " at address 0x" + Long.toHexString(s.pointer) + "\n");

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