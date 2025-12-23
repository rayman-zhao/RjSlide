REM swift build

jar -cf RjSlide.jar -C .build\plugins\outputs\rjslide\RjSlide\destination\JavaCompilerPlugin\Java\ dev\

java -cp .\RjSlide.jar -Djava.library.path=.build/debug "dev.swiftworks.ruslan.Slide" "C:\Users\zhaoy\Downloads\mushroom.svs"
