package com.example.perform_ai

import android.content.Context
import android.content.res.AssetManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.gpu.CompatibilityList
import org.tensorflow.lite.gpu.GpuDelegate
import org.tensorflow.lite.nnapi.NnApiDelegate
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker.FaceLandmarkerOptions
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker.PoseLandmarkerOptions
import java.io.ByteArrayOutputStream
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.*
import kotlin.math.*

class AiAnalysisPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    // TFLite Interpreters and Delegates
    private var faceInterpreter: Interpreter? = null
    private var faceGpuDelegate: GpuDelegate? = null
    private var faceNnApiDelegate: NnApiDelegate? = null
    private var faceLandmarker: FaceLandmarker? = null
    private var poseLandmarker: PoseLandmarker? = null

    // Standardizers
    private var faceMean = FloatArray(404)
    private var faceStd = FloatArray(404)

    // Constant definitions for feature extraction
    private val selectedFaceLandmarks = intArrayOf(
        1, 2, 4, 5, 6, 7, 13, 14, 17, 19, 33, 46, 52, 53, 55, 58, 61, 63, 65, 66,
        70, 78, 80, 81, 82, 84, 87, 88, 91, 93, 94, 95, 98, 105, 107, 132, 133, 136,
        144, 145, 146, 148, 149, 150, 152, 153, 154, 155, 157, 158, 159, 160, 161,
        163, 168, 172, 173, 176, 178, 181, 191, 195, 197, 234, 246, 249, 263, 276,
        282, 283, 285, 288, 291, 293, 295, 296, 300, 308, 310, 311, 312, 314, 317,
        318, 321, 323, 324, 327, 334, 336, 361, 362, 365, 373, 374, 375, 377, 378,
        379, 380, 381, 382, 384, 385, 386, 387, 388, 390, 397, 398, 400, 402, 405,
        415, 454, 466
    )

    private val leftEyeIndices = intArrayOf(33, 7, 163, 144, 145, 153, 154, 155, 133, 246, 161, 160, 159, 158, 157, 173)
    private val rightEyeIndices = intArrayOf(263, 249, 390, 373, 374, 380, 381, 382, 362, 466, 388, 387, 386, 385, 384, 398)

    private val outerLipIndices = intArrayOf(61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 78)
    private val innerLipIndices = intArrayOf(78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95)

    private val angleTriplesFace = arrayOf(
        intArrayOf(61, 13, 291), intArrayOf(61, 14, 291), intArrayOf(78, 13, 308),
        intArrayOf(78, 14, 308), intArrayOf(61, 0, 291), intArrayOf(13, 61, 14),
        intArrayOf(13, 291, 14), intArrayOf(78, 61, 95), intArrayOf(308, 291, 324),
        intArrayOf(33, 159, 133), intArrayOf(33, 145, 133), intArrayOf(263, 386, 362),
        intArrayOf(263, 374, 362), intArrayOf(70, 105, 107), intArrayOf(336, 334, 300),
        intArrayOf(55, 65, 52), intArrayOf(285, 295, 282), intArrayOf(234, 1, 454),
        intArrayOf(93, 1, 323), intArrayOf(152, 17, 0)
    )



    private val faceLabels = arrayOf("neutral", "happy", "sad", "surprise", "fear", "disgust", "angry", "contempt")
    private val bodyLabels = arrayOf("neutral", "happy", "sad", "surprise", "fear", "disgust", "angry")

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.perform_ai/ai_analysis")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.example.perform_ai/ai_analysis_stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        closeInterpreters()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val success = initializeModels()
                result.success(success)
            }
            "startProcessing" -> {
                result.success(null)
            }
            "stopProcessing" -> {
                result.success(null)
            }
            "analyzeFrame" -> {
                // Dynamic analysis of landmarks passed from Flutter Dart
                val faceLms = call.argument<List<List<Double>>>("faceLandmarks")
                val poseLms = call.argument<List<List<Double>>>("poseLandmarks")
                val view = call.argument<String>("view") ?: "front"

                val analysisResult = processFrame(faceLms, poseLms, view)
                result.success(analysisResult)
            }
            "processImageFrame" -> {
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val rotation = call.argument<Int>("rotation") ?: 0
                val yPlane = call.argument<ByteArray>("yPlane")
                val uPlane = call.argument<ByteArray>("uPlane")
                val vPlane = call.argument<ByteArray>("vPlane")
                val yRowStride = call.argument<Int>("yRowStride") ?: 0
                val uRowStride = call.argument<Int>("uRowStride") ?: 0
                val vRowStride = call.argument<Int>("vRowStride") ?: 0
                val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 0
                val view = call.argument<String>("view") ?: "front"

                if (yPlane == null || uPlane == null || vPlane == null || width == 0 || height == 0) {
                    result.error("INVALID_ARGUMENTS", "Missing frame data planes", null)
                } else {
                    Thread {
                        try {
                            val nv21Bytes = yuv420ToNv21(
                                width, height, yPlane, uPlane, vPlane,
                                yRowStride, uRowStride, vRowStride, uvPixelStride
                            )

                            val yuvImage = YuvImage(nv21Bytes, ImageFormat.NV21, width, height, null)
                            val out = ByteArrayOutputStream()
                            yuvImage.compressToJpeg(Rect(0, 0, width, height), 90, out)
                            val jpegBytes = out.toByteArray()
                            var bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

                            if (rotation != 0) {
                                val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
                                bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                            }

                            val mpImage = com.google.mediapipe.framework.image.BitmapImageBuilder(bitmap).build()

                            val faceLandmarkResult = faceLandmarker?.detect(mpImage)
                            val poseLandmarkResult = poseLandmarker?.detect(mpImage)

                            val faceLmsMapped = ArrayList<List<Double>>()
                            if (faceLandmarkResult != null && faceLandmarkResult.faceLandmarks().isNotEmpty()) {
                                val landmarks = faceLandmarkResult.faceLandmarks()[0]
                                for (lm in landmarks) {
                                    faceLmsMapped.add(listOf(lm.x().toDouble(), lm.y().toDouble(), lm.z().toDouble()))
                                }
                            }

                            val poseLmsMapped = ArrayList<List<Double>>()
                            if (poseLandmarkResult != null && poseLandmarkResult.landmarks().isNotEmpty()) {
                                val landmarks = poseLandmarkResult.landmarks()[0]
                                 for (lm in landmarks) {
                                     val visibilityOpt = lm.visibility()
                                     val visibility = if (visibilityOpt.isPresent) visibilityOpt.get().toDouble() else 0.9
                                     poseLmsMapped.add(listOf(lm.x().toDouble(), lm.y().toDouble(), lm.z().toDouble(), visibility))
                                 }
                            }

                            val analysisResult = processFrame(
                                if (faceLmsMapped.isEmpty()) null else faceLmsMapped,
                                if (poseLmsMapped.isEmpty()) null else poseLmsMapped,
                                view
                            )

                            val response = HashMap<String, Any>()
                            response["faceResult"] = analysisResult["faceResult"] as Map<*, *>
                            response["bodyResult"] = analysisResult["bodyResult"] as Map<*, *>
                            response["faceLandmarks"] = faceLmsMapped
                            response["poseLandmarks"] = poseLmsMapped
                            response["timestamp"] = System.currentTimeMillis()

                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.success(response)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.error("PROCESSING_FAILED", e.message, null)
                            }
                        }
                    }.start()
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun initializeModels(): Boolean {
        try {
            closeInterpreters()

            val assetManager = context.assets

            // 1. Load Standardizers
            loadFaceStandardizer(assetManager)

            // 2. Setup GPU Options
            val compatibilityList = CompatibilityList()
            val faceOptions = Interpreter.Options()

            if (compatibilityList.isDelegateSupportedOnThisDevice) {
                val gpuOptions = compatibilityList.bestOptionsForThisDevice
                faceGpuDelegate = GpuDelegate(gpuOptions)
                faceOptions.addDelegate(faceGpuDelegate)
            } else {
                faceNnApiDelegate = NnApiDelegate()
                faceOptions.addDelegate(faceNnApiDelegate)
            }

            // 3. Load Models
            val faceModelBuffer = loadModelFile(assetManager, "flutter_assets/assets/models/fer/emotion_mlp_float32.tflite")

            faceInterpreter = Interpreter(faceModelBuffer, faceOptions)

            // 4. Initialize MediaPipe Landmarkers
            val landmarkSuccess = initializeLandmarkers(assetManager)
            if (!landmarkSuccess) {
                return false
            }

            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun initializeLandmarkers(assetManager: AssetManager): Boolean {
        try {
            val faceBaseOptions = BaseOptions.builder()
                .setModelAssetPath("flutter_assets/assets/models/face_landmarker.task")
                .build()
            val faceOptions = FaceLandmarkerOptions.builder()
                .setBaseOptions(faceBaseOptions)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setRunningMode(RunningMode.IMAGE)
                .build()
            faceLandmarker = FaceLandmarker.createFromOptions(context, faceOptions)

            val poseBaseOptions = BaseOptions.builder()
                .setModelAssetPath("flutter_assets/assets/models/pose_landmarker_full.task")
                .build()
            val poseOptions = PoseLandmarkerOptions.builder()
                .setBaseOptions(poseBaseOptions)
                .setMinPoseDetectionConfidence(0.5f)
                .setMinPosePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setRunningMode(RunningMode.IMAGE)
                .build()
            poseLandmarker = PoseLandmarker.createFromOptions(context, poseOptions)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun yuv420ToNv21(
        width: Int, height: Int,
        yPlane: ByteArray, uPlane: ByteArray, vPlane: ByteArray,
        yRowStride: Int, uRowStride: Int, vRowStride: Int, uvPixelStride: Int
    ): ByteArray {
        val nv21 = ByteArray(width * height * 3 / 2)
        var idY = 0
        for (y in 0 until height) {
            System.arraycopy(yPlane, y * yRowStride, nv21, idY, width)
            idY += width
        }
        var idUV = width * height
        for (y in 0 until height / 2) {
            val uOffset = y * uRowStride
            val vOffset = y * vRowStride
            for (x in 0 until width / 2) {
                nv21[idUV++] = vPlane[vOffset + x * uvPixelStride]
                nv21[idUV++] = uPlane[uOffset + x * uvPixelStride]
            }
        }
        return nv21
    }

    private fun loadModelFile(assetManager: AssetManager, modelPath: String): MappedByteBuffer {
        val fileDescriptor = assetManager.openFd(modelPath)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    private fun loadFaceStandardizer(assetManager: AssetManager) {
        val jsonString = assetManager.open("flutter_assets/assets/models/fer/feature_standardizer.json").bufferedReader().use { it.readText() }
        val jsonObject = JSONObject(jsonString)
        val meanArray = jsonObject.getJSONArray("mean")
        val stdArray = jsonObject.getJSONArray("std")

        for (i in 0 until 404) {
            faceMean[i] = meanArray.getDouble(i).toFloat()
            faceStd[i] = stdArray.getDouble(i).toFloat()
        }
    }

    private fun closeInterpreters() {
        faceInterpreter?.close()
        faceInterpreter = null
        faceGpuDelegate?.close()
        faceGpuDelegate = null
        faceNnApiDelegate?.close()
        faceNnApiDelegate = null
    }

    private fun processFrame(faceLms: List<List<Double>>?, poseLms: List<List<Double>>?, view: String): Map<String, Any> {
        val result = HashMap<String, Any>()

        // 1. Process Face
        val faceResult = HashMap<String, Any>()
        if (faceLms == null || faceLms.size < 468) {
            faceResult["status"] = 1 // FaceStatus.noFace
            faceResult["emotion"] = "neutral"
            faceResult["confidences"] = getEmptyConfidences(faceLabels)
        } else {
            try {
                val features = extractFaceFeatures(faceLms)
                val standardizedFeatures = FloatArray(404)
                for (i in 0 until 404) {
                    standardizedFeatures[i] = (features[i] - faceMean[i]) / (faceStd[i] + 1e-8f)
                }

                // Check angle quality gate
                val yawProxyIndex = 360 // coordinate features = 348 + cheek offset index
                val yaw = features[yawProxyIndex]
                if (abs(yaw) > 0.6f) {
                    faceResult["status"] = 2 // FaceStatus.insufficientFaceAngle
                    faceResult["emotion"] = "neutral"
                    faceResult["confidences"] = getEmptyConfidences(faceLabels)
                } else {
                    val inputVal = arrayOf(standardizedFeatures)
                    val outputVal = arrayOf(FloatArray(8))
                    faceInterpreter?.run(inputVal, outputVal)

                    val confidences = outputVal[0]
                    val softConfs = softmax(confidences)
                    val maxIdx = getMaxIndex(softConfs)

                    if (softConfs[maxIdx] < 0.05f) {
                        faceResult["status"] = 3 // FaceStatus.uncertain
                        faceResult["emotion"] = "neutral"
                        faceResult["confidences"] = mapConfidences(faceLabels, softConfs)
                    } else {
                        faceResult["status"] = 0 // FaceStatus.active
                        faceResult["emotion"] = faceLabels[maxIdx]
                        faceResult["confidences"] = mapConfidences(faceLabels, softConfs)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                faceResult["status"] = 3
                faceResult["emotion"] = "neutral"
                faceResult["confidences"] = getEmptyConfidences(faceLabels)
            }
        }

        // 2. Process Body Motion (TCN) - Dummy Stub (TCN model disabled)
        val bodyResult = HashMap<String, Any>()
        bodyResult["status"] = 2 // BodyStatus.uncertain
        bodyResult["emotion"] = "neutral"
        bodyResult["confidences"] = getEmptyConfidences(bodyLabels)

        result["faceResult"] = faceResult
        result["bodyResult"] = bodyResult
        result["timestamp"] = System.currentTimeMillis()

        // Push event to stream automatically if listeners active
        eventSink?.success(result)

        return result
    }

    // Mathematical helper operations
    private fun getEmptyConfidences(labels: Array<String>): Map<String, Double> {
        val map = HashMap<String, Double>()
        for (label in labels) {
            map[label] = 0.0
        }
        return map
    }

    private fun mapConfidences(labels: Array<String>, values: FloatArray): Map<String, Double> {
        val map = HashMap<String, Double>()
        for (i in labels.indices) {
            map[labels[i]] = values[i].toDouble()
        }
        return map
    }

    private fun softmax(logits: FloatArray): FloatArray {
        var max = Float.NEGATIVE_INFINITY
        for (v in logits) {
            if (v > max) max = v
        }
        var sum = 0.0f
        val exp = FloatArray(logits.size)
        for (i in logits.indices) {
            exp[i] = exp(logits[i] - max)
            sum += exp[i]
        }
        for (i in exp.indices) {
            exp[i] /= (sum + 1e-8f)
        }
        return exp
    }

    private fun getMaxIndex(arr: FloatArray): Int {
        var maxIdx = 0
        var maxVal = arr[0]
        for (i in 1 until arr.size) {
            if (arr[i] > maxVal) {
                maxVal = arr[i]
                maxIdx = i
            }
        }
        return maxIdx
    }

    private fun dist2d(p1: FloatArray, p2: FloatArray): Float {
        val dx = p1[0] - p2[0]
        val dy = p1[1] - p2[1]
        return sqrt(dx * dx + dy * dy)
    }

    private fun dist2d(pts: List<List<Double>>, a: Int, b: Int): Float {
        val dx = pts[a][0] - pts[b][0]
        val dy = pts[a][1] - pts[b][1]
        return sqrt(dx * dx + dy * dy).toFloat()
    }

    private fun angle2dOverPi(pa: FloatArray, pb: FloatArray, pc: FloatArray): Float {
        val ux = pa[0] - pb[0]
        val uy = pa[1] - pb[1]
        val vx = pc[0] - pb[0]
        val vy = pc[1] - pb[1]
        val cross = abs(ux * vy - uy * vx)
        val dot = ux * vx + uy * vy
        return (atan2(cross, dot) / Math.PI).toFloat()
    }

    private fun polygonArea(pts: List<FloatArray>, indices: IntArray): Float {
        var area = 0.0f
        val numPoints = indices.size
        for (i in 0 until numPoints) {
          val j = (i + 1) % numPoints
          val p1 = pts[indices[i]]
          val p2 = pts[indices[j]]
          area += p1[0] * p2[1] - p2[0] * p1[1]
        }
        return abs(area / 2.0f)
    }

    private fun meanPoint(pts: List<List<Double>>, indices: IntArray): FloatArray {
        var sx = 0.0
        var sy = 0.0
        var sz = 0.0
        for (idx in indices) {
            sx += pts[idx][0]
            sy += pts[idx][1]
            sz += pts[idx][2]
        }
        val len = indices.size.toDouble()
        return floatArrayOf((sx / len).toFloat(), (sy / len).toFloat(), (sz / len).toFloat())
    }

    private fun extractFaceFeatures(rawLms: List<List<Double>>): FloatArray {
        // Face Alignment
        val leftEyeCenter = meanPoint(rawLms, leftEyeIndices)
        val rightEyeCenter = meanPoint(rawLms, rightEyeIndices)

        val eyeCenter = floatArrayOf(
            (leftEyeCenter[0] + rightEyeCenter[0]) / 2f,
            (leftEyeCenter[1] + rightEyeCenter[1]) / 2f,
            (leftEyeCenter[2] + rightEyeCenter[2]) / 2f
        )

        val eyeVec = floatArrayOf(
            rightEyeCenter[0] - leftEyeCenter[0],
            rightEyeCenter[1] - leftEyeCenter[1]
        )

        val eyeDist = sqrt(eyeVec[0] * eyeVec[0] + eyeVec[1] * eyeVec[1]) + 1e-6f
        val roll = atan2(eyeVec[1], eyeVec[0])

        val pts = ArrayList<FloatArray>()
        for (i in rawLms.indices) {
            val p = rawLms[i]
            val dx = (p[0] - eyeCenter[0]).toFloat()
            val dy = (p[1] - eyeCenter[1]).toFloat()
            val dz = (p[2] - eyeCenter[2]).toFloat()

            val c = cos(-roll)
            val s = sin(-roll)

            val rx = (c * dx - s * dy) / eyeDist
            val ry = (s * dx + c * dy) / eyeDist
            val rz = dz / eyeDist
            pts.add(floatArrayOf(rx, ry, rz))
        }

        val features = ArrayList<Float>()

        // Coordinate features (116 * 3 = 348)
        for (idx in selectedFaceLandmarks) {
            features.add(pts[idx][0])
            features.add(pts[idx][1])
            features.add(pts[idx][2])
        }

        // Engineered features
        val mouthWidth = dist2d(pts[61], pts[291])
        val mouthOpen1 = dist2d(pts[13], pts[14])
        val mouthOpen2 = dist2d(pts[82], pts[312])
        val mouthOpen3 = dist2d(pts[87], pts[317])
        val mouthOpen = (mouthOpen1 + mouthOpen2 + mouthOpen3) / 3f
        val mar = mouthOpen / (mouthWidth + 1e-6f)

        val outerMouthArea = polygonArea(pts, outerLipIndices)
        val innerMouthArea = polygonArea(pts, innerLipIndices)

        val mouthCenter = floatArrayOf(
            (pts[61][0] + pts[291][0]) / 2f,
            (pts[61][1] + pts[291][1]) / 2f
        )
        val leftCornerLift = pts[61][1] - mouthCenter[1]
        val rightCornerLift = pts[291][1] - mouthCenter[1]
        val cornerLiftMean = (leftCornerLift + rightCornerLift) / 2f
        val cornerLiftDiff = abs(leftCornerLift - rightCornerLift)

        val mouthSlope = (atan2(pts[291][1] - pts[61][1], pts[291][0] - pts[61][0] + 1e-6f) / Math.PI).toFloat()

        features.addAll(listOf(
            mouthWidth, mouthOpen1, mouthOpen2, mouthOpen3, mouthOpen, mar,
            outerMouthArea, innerMouthArea, leftCornerLift, rightCornerLift,
            cornerLiftMean, cornerLiftDiff, mouthSlope
        ))

        val leftEyeWidth = dist2d(pts[33], pts[133])
        val rightEyeWidth = dist2d(pts[263], pts[362])

        val leftEar = (
            dist2d(pts[159], pts[145]) +
            dist2d(pts[158], pts[153]) +
            dist2d(pts[160], pts[144])
        ) / (3f * leftEyeWidth + 1e-6f)

        val rightEar = (
            dist2d(pts[386], pts[374]) +
            dist2d(pts[385], pts[380]) +
            dist2d(pts[387], pts[373])
        ) / (3f * rightEyeWidth + 1e-6f)

        val earMean = (leftEar + rightEar) / 2f
        val earDiff = abs(leftEar - rightEar)

        features.addAll(listOf(leftEyeWidth, rightEyeWidth, leftEar, rightEar, earMean, earDiff))

        // Eyebrows
        val leftEyeCenterNorm = meanPoint(rawLms.map { it.map { v -> v } }, leftEyeIndices) // raw-based average inside normalization scale
        // Wait, let's just average pts left eye to make it clean:
        var lx = 0f; var ly = 0f
        for (idx in leftEyeIndices) { lx += pts[idx][0]; ly += pts[idx][1] }
        val leftEyeCenterP = floatArrayOf(lx / leftEyeIndices.size, ly / leftEyeIndices.size)

        var rx = 0f; var ry = 0f
        for (idx in rightEyeIndices) { rx += pts[idx][0]; ry += pts[idx][1] }
        val rightEyeCenterP = floatArrayOf(rx / rightEyeIndices.size, ry / rightEyeIndices.size)

        var lbx = 0f; var lby = 0f
        val leftBrowIndices = intArrayOf(70, 63, 105, 66, 107)
        for (idx in leftBrowIndices) { lbx += pts[idx][0]; lby += pts[idx][1] }
        val leftBrowCenterP = floatArrayOf(lbx / leftBrowIndices.size, lby / leftBrowIndices.size)

        var rbx = 0f; var rby = 0f
        val rightBrowIndices = intArrayOf(336, 296, 334, 293, 300)
        for (idx in rightBrowIndices) { rbx += pts[idx][0]; rby += pts[idx][1] }
        val rightBrowCenterP = floatArrayOf(rbx / rightBrowIndices.size, rby / rightBrowIndices.size)

        val leftBrowRaise = dist2d(leftBrowCenterP, leftEyeCenterP)
        val rightBrowRaise = dist2d(rightBrowCenterP, rightEyeCenterP)

        val browRaiseMean = (leftBrowRaise + rightBrowRaise) / 2f
        val browRaiseDiff = abs(leftBrowRaise - rightBrowRaise)

        val innerBrowDistance = dist2d(pts[107], pts[336])

        features.addAll(listOf(leftBrowRaise, rightBrowRaise, browRaiseMean, browRaiseDiff, innerBrowDistance))

        val leftCheekNose = dist2d(pts[234], pts[1])
        val rightCheekNose = dist2d(pts[454], pts[1])
        val cheekDiff = abs(leftCheekNose - rightCheekNose)

        val chinMouth = dist2d(pts[152], pts[17])
        val noseMouth = dist2d(pts[1], pts[13])
        val noseChin = dist2d(pts[1], pts[152])

        val yawProxy = (leftCheekNose - rightCheekNose) / (leftCheekNose + rightCheekNose + 1e-6f)
        val pitchProxy = pts[1][1] - ((pts[33][1] + pts[263][1]) / 2f)

        features.addAll(listOf(
            leftCheekNose, rightCheekNose, cheekDiff, chinMouth, noseMouth, noseChin,
            yawProxy, pitchProxy, (roll / Math.PI).toFloat()
        ))

        features.addAll(listOf(cornerLiftDiff, earDiff, browRaiseDiff))

        for (triple in angleTriplesFace) {
            features.add(angle2dOverPi(pts[triple[0]], pts[triple[1]], pts[triple[2]]))
        }

        val out = FloatArray(404)
        for (i in 0 until 404) {
            val v = features[i]
            out[i] = if (v.isNaN() || v.isInfinite()) 0f else v
        }
        return out
    }


}
