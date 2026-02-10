REM swift build

jar -cf RjSlide.jar -C .build\plugins\outputs\rjslide\RjSlide\destination\JavaCompilerPlugin\Java\ dev\

REM java -cp .\RjSlide.jar -Djava.library.path=.build/debug "dev.swiftworks.ruslan.Slide" "C:\Users\zhaoy\Downloads\mushroom.svs"
java -cp .\RjSlide.jar -Djava.library.path=.build/debug "dev.swiftworks.ruslan.Register" "./TestData/HE.jpg" "./TestData/IHC.jpg" "./TestOut/"
