package dev.swiftworks.ruslan;

import java.nio.file.*;

public class Slide implements AutoCloseable {
    static {
        System.loadLibrary("RjSlide");
    }

    public long nativeSlide = 0;

    public Slide(String path) {
        nativeSlide = create(path);
    }

    @Override
    public void close() {
        release();
    }

    private native long create(String path);
    private native void release();
    public native byte[] getMacro();
    public native byte[] getLabel();
    public native byte[] getTile(String imageId, int tier, int level, int x, int y);
    public native byte[] getThumbnail(int maxSize);
    public native String getUploadSlideDTO();

    public static void main(String[] args) {
        try (Slide s = new Slide(args[0])) {
            System.out.print("Open " + args[0] + " at address 0x" + Long.toHexString(s.nativeSlide) + "\n");

            byte[] macro = s.getMacro();
            System.out.println("Got macro image in " + macro.length);
            //Files.write(Paths.get("macro.jpg"), macro);

            byte[] label = s.getLabel();
            System.out.println("Got label image in " + label.length);
            //Files.write(Paths.get("label.jpg"), label);

            byte[] tile = s.getTile("f", 0, 0, 0, 0);
            System.out.println("Got tile in " + tile.length);
            //Files.write(Paths.get("tile.jpg"), tile);

            byte[] thumbnail = s.getThumbnail(256);
            System.out.println("Got thumbnail in " + thumbnail.length);
            //Files.write(Paths.get("thumbnail.jpg"), thumbnail);

            System.out.println("UploadSlideDTO : " + s.getUploadSlideDTO());

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}