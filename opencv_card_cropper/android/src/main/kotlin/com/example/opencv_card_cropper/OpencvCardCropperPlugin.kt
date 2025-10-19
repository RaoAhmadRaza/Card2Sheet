package com.example.opencv_card_cropper

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import org.opencv.android.OpenCVLoader
import java.io.File
import java.io.FileOutputStream

/** OpencvCardCropperPlugin */
class OpencvCardCropperPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "opencv_card_cropper")
    channel.setMethodCallHandler(this)
    try {
      System.loadLibrary("opencv_java4")
    } catch (_: UnsatisfiedLinkError) {
      // Try OpenCV loader fallback for debug builds
      OpenCVLoader.initDebug()
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
      "deskewCard" -> {
        val args = call.arguments as? Map<*, *>
        var imagePath = args?.get("imagePath") as? String
        if (imagePath.isNullOrEmpty()) {
          imagePath = args?.get("path") as? String
        }
        if (imagePath.isNullOrEmpty()) {
          result.error("ARG", "imagePath is required", null)
          return
        }
        @Suppress("UNCHECKED_CAST")
        val roi = args["roi"] as? Map<String, Number>
        try {
          val outPath = deskewCard(imagePath, roi)
          result.success(outPath)
        } catch (e: Exception) {
          result.error("CROP_ERROR", e.message, null)
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun deskewCard(imagePath: String, roi: Map<String, Number>?): String {
    val srcBitmap = BitmapFactory.decodeFile(imagePath)
      ?: throw IllegalArgumentException("Unable to decode image: $imagePath")

    var srcMat = Mat()
    Utils.bitmapToMat(srcBitmap, srcMat)

    // Optional ROI crop for speed/accuracy
    if (roi != null) {
      val x = roi["x"]?.toInt() ?: 0
      val y = roi["y"]?.toInt() ?: 0
      val w = roi["width"]?.toInt() ?: srcMat.width()
      val h = roi["height"]?.toInt() ?: srcMat.height()
      val rx = Math.max(0, Math.min(x, srcMat.width() - 1))
      val ry = Math.max(0, Math.min(y, srcMat.height() - 1))
      val rw = Math.max(1, Math.min(w, srcMat.width() - rx))
      val rh = Math.max(1, Math.min(h, srcMat.height() - ry))
      srcMat = Mat(srcMat, Rect(rx, ry, rw, rh)).clone()
    }

    val gray = Mat()
    Imgproc.cvtColor(srcMat, gray, Imgproc.COLOR_BGR2GRAY)
    Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)
    Imgproc.Canny(gray, gray, 75.0, 200.0)

    val contours = ArrayList<MatOfPoint>()
    val hierarchy = Mat()
    Imgproc.findContours(gray, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

    var maxArea = 0.0
    var cardContour: MatOfPoint2f? = null
    for (contour in contours) {
      val contour2f = MatOfPoint2f(*contour.toArray())
      val peri = Imgproc.arcLength(contour2f, true)
      val approx = MatOfPoint2f()
      Imgproc.approxPolyDP(contour2f, approx, 0.02 * peri, true)
      val area = Math.abs(Imgproc.contourArea(approx))
      if (area > maxArea && approx.total() == 4L) {
        maxArea = area
        cardContour = approx
      }
    }

    if (cardContour == null) {
      // If no quad found, return original image path
      return imagePath
    }

    val points = cardContour!!.toArray()
    // Sort by y, then x to get TL/TR and BL/BR groups
    val sortedByY = points.sortedBy { it.y }
    val top = sortedByY.take(2).sortedBy { it.x }
    val bottom = sortedByY.takeLast(2).sortedBy { it.x }
    val tl = top[0]
    val tr = top[1]
    val br = bottom[1]
    val bl = bottom[0]

    val widthA = Math.hypot((br.x - bl.x), (br.y - bl.y))
    val widthB = Math.hypot((tr.x - tl.x), (tr.y - tl.y))
    val maxWidth = Math.max(widthA, widthB).toInt().coerceAtLeast(1)

    val heightA = Math.hypot((tr.x - br.x), (tr.y - br.y))
    val heightB = Math.hypot((tl.x - bl.x), (tl.y - bl.y))
    val maxHeight = Math.max(heightA, heightB).toInt().coerceAtLeast(1)

    val srcQuad = MatOfPoint2f(tl, tr, br, bl)
    val dstQuad = MatOfPoint2f(
      Point(0.0, 0.0),
      Point(maxWidth - 1.0, 0.0),
      Point(maxWidth - 1.0, maxHeight - 1.0),
      Point(0.0, maxHeight - 1.0)
    )

    val m = Imgproc.getPerspectiveTransform(srcQuad, dstQuad)
    val warped = Mat()
    Imgproc.warpPerspective(srcMat, warped, m, Size(maxWidth.toDouble(), maxHeight.toDouble()))

    val resultBitmap = Bitmap.createBitmap(maxWidth, maxHeight, Bitmap.Config.ARGB_8888)
    Utils.matToBitmap(warped, resultBitmap)

    // Save alongside original
    val outputFile = File(
      if (imagePath.endsWith(".jpg", true) || imagePath.endsWith(".jpeg", true))
        imagePath.substring(0, imagePath.lastIndexOf('.')) + "_deskewed.jpg"
      else imagePath + "_deskewed.jpg"
    )
    FileOutputStream(outputFile).use { out ->
      resultBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
    }

    return outputFile.absolutePath
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
