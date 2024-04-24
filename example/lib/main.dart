import 'package:example/animated_example_widget.dart';
import 'package:example/animated_example_buttons.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:render/render.dart';
import 'animated_example_controller.dart';
import 'animated_example_popup.dart';

class ProResFormat extends MotionFormat {
    const ProResFormat({
        super.audio,
        super.scale,
        super.interpolation = Interpolation.bicubic,
    }) : super(
            handling: FormatHandling.video,
            processShare: 0.2,
        );

    @override
    ProResFormat copyWith({
        RenderScale? scale,
        Interpolation? interpolation,
    }) {
        return ProResFormat(
            scale: scale ?? this.scale,
            interpolation: interpolation ?? this.interpolation,
        );
    }

    @override
    FFmpegRenderOperation processor({
        required String inputPath,
        required String outputPath,
        required double frameRate,
    }) {
        // final audioInput = audio != null && audio!.isNotEmpty
        //     ? audio!.map((e) => "-i??${e.path}").join('??')
        //     : null;
        // final mergeAudiosList = audio != null && audio!.isNotEmpty
        //     ? ";${List.generate(audio!.length, (index) => "[${index + 1}:a]" // list audio
        //             "atrim=start=${audio![index].startTime}" // start time of audio
        //             ":${"end=${audio![index].endTime}"}[a${index + 1}];").join()}" // end time of audio
        //         "${List.generate(audio!.length, (index) => "[a${index + 1}]").join()}" // list audio
        //         "amix=inputs=${audio!.length}[a]" // merge audios
        //     : "";
        // final overwriteAudioExecution = audio != null &&
        //         audio!.isNotEmpty // merge audios with existing (none)
        //     ? "-map??[v]??-map??[a]??-c:v??prores_videotoolbox??-c:a??"
        //         "aac??-shortest??-pix_fmt??yuv420p??-vsync??2"
        //     : "-map??[v]??-c:v??prores_videotoolbox-pix_fmt??yuv420p";
        final args = <String?>[
            "-i",
            inputPath,
            "-c:v",
            "prores_videotoolbox",
            // audioInput,
            // "-filter_complex",
            // "[0:v]${scalingFilter != null ? "$scalingFilter," : ""}"
            //     "setpts=N/($frameRate*TB)[v]$mergeAudiosList",
            // overwriteAudioExecution,
            "-y",
            outputPath, // write output file
        ];
        print("ffmpeg args: $args");
        return FFmpegRenderOperation(args);
    }

    @override
    String get extension => "mov";
}

void main() {
    runApp(const MyApp());
}

class MyApp extends StatelessWidget {
    const MyApp({super.key});

    // This widget is the root of your application.
    @override
    Widget build(BuildContext context) {
        return const MaterialApp(
            home: MyHomePage(),
        );
    }
}

class MyHomePage extends StatefulWidget {
    const MyHomePage({super.key});

    @override
    State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
    late final Future<ExampleAnimationController> init;
    final RenderController renderController =
        RenderController(logLevel: LogLevel.debug);

    @override
    void initState() {
        init = ExampleAnimationController.create(this);
        super.initState();
    }

    @override
    Widget build(BuildContext context) {
        init.then((value) => print("done"));
        return Scaffold(
            appBar: AppBar(
                title: const Text("Render Example"),
            ),
            body: FutureBuilder(
                future: init,
                builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.connectionState ==
                            ConnectionState.done &&
                        snapshot.hasData) {
                        final functionController = snapshot.data!;
                        return Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                    SizedBox(
                                        width: 576,
                                        height: 324,
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Render(
                                                controller: renderController,
                                                child: SizedBox(
                                                    width: 3840,
                                                    height: 2160,
                                                    child:
                                                        AnimatedExampleWidget(
                                                        exampleAnimationController:
                                                            functionController,
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),
                                    const Spacer(),
                                    NavigationButtons(
                                        motionRenderCallback: () async {
                                            functionController.play();
                                            final stream = renderController
                                                .captureMotionWithStream(
                                                functionController.duration,
                                                settings: const MotionSettings(
                                                    pixelRatio: 1,
                                                    frameRate: 30,
                                                    simultaneousCaptureHandlers:
                                                        6,
                                                ),
                                                logInConsole: true,
                                                format: const ProResFormat(),
                                            );
                                            setState(() {
                                                functionController
                                                    .attach(stream);
                                            });
                                            final result = await stream
                                                .firstWhere((event) =>
                                                    event.isResult ||
                                                    event.isFatalError);
                                            if (result.isFatalError) return;
                                            displayResult(
                                                result as RenderResult);
                                        },
                                        exampleAnimationController:
                                            functionController,
                                        imageRenderCallback: () async {
                                            final imageResult =
                                                await renderController
                                                    .captureImage(
                                                format: ImageFormat.png,
                                                settings: const ImageSettings(
                                                    pixelRatio: 1,
                                                ),
                                            );
                                            print(
                                                "imageResult.output.path: ${imageResult.output.path}");
                                            displayResult(imageResult);
                                        },
                                    ),
                                ],
                            ),
                        );
                    } else {
                        return Center(
                            child: Text(
                                "Error loading: ${snapshot.error}",
                                style: const TextStyle(
                                    color: Colors.red,
                                ),
                            ),
                        );
                    }
                },
            ),
        );
    }

    Future<void> displayResult(RenderResult result,
        [bool saveToGallery = false]) async {
        print("file exits: ${await result.output.exists()}");
        if (mounted) {
            showDialog(
                context: context,
                builder: (BuildContext context) => AnimatedExamplePopUp(
                    context: context,
                    result: result,
                ),
            );
        }
        if (saveToGallery) {
            GallerySaver.saveImage(result.output.path)
                .then((value) => print("saved export to gallery"));
        }
    }
}
