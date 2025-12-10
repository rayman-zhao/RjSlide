REM swift build
%JAVA_HOME%\bin\java ^
-cp .build/plugins/outputs/RjSlide/RjSlide/destination/JavaCompilerPlugin/Java ^
-Djava.library.path=.build/debug ^
"dev.swiftworks.ruslan.Slide" "C:\Users\zhaoy\Downloads\mushroom.svs"
