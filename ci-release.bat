REM swift build

jar -cf .build/release/RjSlide.jar -C .build/plugins/outputs/rjslide/RjSlide/destination/JavaCompilerPlugin/Java/ dev/

java -cp .build/release/RjSlide.jar -Djava.library.path=.build/release "dev.swiftworks.ruslan.Slide" "C:\Users\zhaoy\Downloads\mushroom.svs"
java -cp .build/release/RjSlide.jar -Djava.library.path=.build/release "dev.swiftworks.ruslan.Register" "./TestData/HE.png" "./TestData/IHC.png" "./TestOut"
