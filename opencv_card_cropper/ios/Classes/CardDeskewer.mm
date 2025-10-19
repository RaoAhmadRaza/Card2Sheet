#import "CardDeskewer.h"
#import <opencv2/opencv.hpp>

using namespace cv;

@implementation CardDeskewer

+ (NSString *)deskewAtPath:(NSString *)imagePath
                         x:(NSNumber *)x
                         y:(NSNumber *)y
                     width:(NSNumber *)width
                    height:(NSNumber *)height {
  @autoreleasepool {
    std::string inPath([imagePath UTF8String]);

    // Read image (color)
    Mat src = imread(inPath, IMREAD_COLOR);
    if (src.empty()) {
      return imagePath; // fail gracefully
    }

    // Optional ROI crop
    if (x && y && width && height) {
      int rx = std::max(0, std::min((int)[x intValue], src.cols - 1));
      int ry = std::max(0, std::min((int)[y intValue], src.rows - 1));
      int rw = std::max(1, std::min((int)[width intValue], src.cols - rx));
      int rh = std::max(1, std::min((int)[height intValue], src.rows - ry));
      Rect roi(rx, ry, rw, rh);
      src = src(roi).clone();
    }

    // Grayscale, blur, Canny
    Mat gray;
    cvtColor(src, gray, COLOR_BGR2GRAY);
    GaussianBlur(gray, gray, Size(5,5), 0);
    Canny(gray, gray, 75, 200);

    // Find contours
    std::vector<std::vector<Point>> contours;
    findContours(gray, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);

    double maxArea = 0.0;
    std::vector<Point2f> card;
    for (const auto &c : contours) {
      std::vector<Point2f> c2f; c2f.reserve(c.size());
      for (const auto &p : c) c2f.emplace_back((float)p.x, (float)p.y);
      double peri = arcLength(c2f, true);
      std::vector<Point2f> approx;
      approxPolyDP(c2f, approx, 0.02 * peri, true);
      double area = fabs(contourArea(approx));
      if (approx.size() == 4 && area > maxArea) {
        maxArea = area;
        card = approx;
      }
    }

    if (card.size() != 4) {
      return imagePath; // no quad found
    }

    // Order points TL, TR, BR, BL
    std::sort(card.begin(), card.end(), [](const Point2f &a, const Point2f &b){ return a.y < b.y; });
    std::vector<Point2f> top = {card[0], card[1]};
    std::vector<Point2f> bottom = {card[2], card[3]};
    std::sort(top.begin(), top.end(), [](const Point2f &a, const Point2f &b){ return a.x < b.x; });
    std::sort(bottom.begin(), bottom.end(), [](const Point2f &a, const Point2f &b){ return a.x < b.x; });
    Point2f tl = top[0], tr = top[1], br = bottom[1], bl = bottom[0];

    double widthA = hypot(br.x - bl.x, br.y - bl.y);
    double widthB = hypot(tr.x - tl.x, tr.y - tl.y);
    int maxWidth = std::max((int)round(widthA), (int)round(widthB));
    double heightA = hypot(tr.x - br.x, tr.y - br.y);
    double heightB = hypot(tl.x - bl.x, tl.y - bl.y);
    int maxHeight = std::max((int)round(heightA), (int)round(heightB));
    maxWidth = std::max(1, maxWidth);
    maxHeight = std::max(1, maxHeight);

    std::vector<Point2f> dst = {
      Point2f(0.f, 0.f),
      Point2f((float)maxWidth - 1, 0.f),
      Point2f((float)maxWidth - 1, (float)maxHeight - 1),
      Point2f(0.f, (float)maxHeight - 1)
    };

    Mat M = getPerspectiveTransform(std::vector<Point2f>{tl, tr, br, bl}, dst);
    Mat warped;
    warpPerspective(src, warped, M, Size(maxWidth, maxHeight));

    // Build output path
    NSString *outPath = imagePath;
    NSRange dot = [outPath rangeOfString:@"." options:NSBackwardsSearch];
    if (dot.location != NSNotFound) {
      outPath = [outPath stringByReplacingCharactersInRange:NSMakeRange(dot.location, outPath.length - dot.location)
                                                 withString:@"_deskewed.jpg"];
    } else {
      outPath = [outPath stringByAppendingString:@"_deskewed.jpg"];
    }

    std::string oPath([outPath UTF8String]);
    imwrite(oPath, warped);
    return outPath;
  }
}

@end
