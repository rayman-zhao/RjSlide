REM swift build

jar -cf .build/debug/RjSlide.jar -C .build/plugins/outputs/rjslide/RjSlide/destination/JavaCompilerPlugin/Java/ dev/

java -cp .build/debug/RjSlide.jar -Djava.library.path=.build/debug "dev.swiftworks.ruslan.Slide" "C:\Users\zhaoy\Downloads\mushroom.svs"
java -cp .build/debug/RjSlide.jar -Djava.library.path=.build/debug "dev.swiftworks.ruslan.Register" "./TestData/HE.png" "./TestData/IHC.png" "./TestOut"
