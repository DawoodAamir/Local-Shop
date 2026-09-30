import SwiftUI

/// Original vector product illustrations; no external image requests or licenses.
struct ProductArt: View {
  let art: String
  var large = false
  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      ZStack {
        Color(red: 0.92, green: 0.89, blue: 0.84)
        Ellipse().fill(Color.black.opacity(0.07)).frame(width: side * 0.58, height: side * 0.065)
          .offset(y: side * 0.31)
        drawing.frame(width: 160, height: 160).scaleEffect(side / 220)
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }.accessibilityHidden(true)
  }
  @ViewBuilder private var drawing: some View {
    switch art {
    case "mug":
      ZStack {
        RoundedRectangle(cornerRadius: 22).stroke(
          Color(red: 0.55, green: 0.31, blue: 0.20), lineWidth: 13
        ).frame(width: 46, height: 61).offset(x: 55, y: 6)
        RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.68, green: 0.42, blue: 0.28)).frame(
          width: 102, height: 105
        ).offset(y: 11)
        Ellipse().fill(Color(red: 0.40, green: 0.24, blue: 0.16)).frame(width: 101, height: 22)
          .offset(y: -39)
        Ellipse().stroke(Color(red: 0.77, green: 0.53, blue: 0.36), lineWidth: 5).frame(
          width: 100, height: 23
        ).offset(y: -40)
      }
    case "tote":
      ZStack {
        RoundedRectangle(cornerRadius: 28).stroke(
          Color(red: 0.41, green: 0.47, blue: 0.33), lineWidth: 10
        ).frame(width: 64, height: 82).offset(y: -36)
        RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.51, green: 0.57, blue: 0.41)).frame(
          width: 115, height: 112
        ).offset(y: 21)
        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 2, height: 90).offset(
          x: -35, y: 23)
        Text("LOCAL").font(.system(size: 16, weight: .medium, design: .serif)).tracking(3)
          .foregroundColor(.white.opacity(0.8)).offset(y: 24)
      }
    case "lamp":
      ZStack {
        RoundedRectangle(cornerRadius: 7).fill(Color(red: 0.46, green: 0.37, blue: 0.25)).frame(
          width: 10, height: 110
        ).offset(y: 12)
        Ellipse().fill(Color(red: 0.58, green: 0.44, blue: 0.24)).frame(width: 91, height: 18)
          .offset(y: 67)
        UnevenShade().fill(Color(red: 0.80, green: 0.65, blue: 0.37)).frame(width: 138, height: 70)
          .offset(y: -33)
        Ellipse().fill(Color(red: 0.92, green: 0.80, blue: 0.56)).frame(width: 138, height: 16)
          .offset(y: 2)
      }
    case "bowl":
      ZStack {
        Ellipse().fill(Color(red: 0.64, green: 0.59, blue: 0.49)).frame(width: 135, height: 88)
          .offset(y: 20)
        Rectangle().fill(Color(red: 0.92, green: 0.89, blue: 0.84)).frame(width: 160, height: 70)
          .offset(y: -40)
        Ellipse().fill(Color(red: 0.82, green: 0.77, blue: 0.66)).frame(width: 135, height: 42)
          .offset(y: -4)
        Ellipse().stroke(Color(red: 0.90, green: 0.85, blue: 0.74), lineWidth: 5).frame(
          width: 132, height: 40
        ).offset(y: -4)
      }
    case "notebook":
      ZStack {
        RoundedRectangle(cornerRadius: 5).fill(Color.white).frame(width: 100, height: 137).offset(
          x: 5, y: 4)
        RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.24, green: 0.32, blue: 0.36)).frame(
          width: 104, height: 140)
        Rectangle().fill(Color.black.opacity(0.18)).frame(width: 5, height: 138).offset(x: -42)
        Text("NOTES").font(.system(size: 12, weight: .medium)).tracking(3).foregroundColor(
          Color(red: 0.84, green: 0.78, blue: 0.62)
        ).offset(y: -28)
      }.rotationEffect(.degrees(-8))
    case "vase":
      ZStack {
        Capsule().fill(Color(red: 0.68, green: 0.43, blue: 0.32)).frame(width: 81, height: 104)
          .offset(y: 20)
        Rectangle().fill(Color(red: 0.68, green: 0.43, blue: 0.32)).frame(width: 35, height: 71)
          .offset(y: -24)
        Ellipse().fill(Color(red: 0.44, green: 0.26, blue: 0.18)).frame(width: 35, height: 9)
          .offset(y: -59)
        Path { p in
          p.move(to: CGPoint(x: 80, y: 27))
          p.addQuadCurve(to: CGPoint(x: 107, y: -12), control: CGPoint(x: 89, y: 0))
        }.stroke(Style.green, lineWidth: 2)
        Ellipse().fill(Style.green).frame(width: 27, height: 12).rotationEffect(.degrees(-30))
          .offset(x: 28, y: -80)
      }
    case "linen":
      ZStack {
        RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.56, green: 0.61, blue: 0.48)).frame(
          width: 115, height: 103
        ).rotationEffect(.degrees(-8)).offset(x: -6, y: -5)
        RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.70, green: 0.73, blue: 0.61)).frame(
          width: 115, height: 103
        ).rotationEffect(.degrees(6)).offset(x: 7, y: 13)
        ForEach(0..<6) { n in
          Rectangle().fill(Color.white.opacity(0.16)).frame(width: 101, height: 1).rotationEffect(
            .degrees(6)
          ).offset(x: 7, y: CGFloat(n * 15 - 22))
        }
      }
    default:
      ZStack {
        Capsule().fill(Color(red: 0.62, green: 0.45, blue: 0.28)).frame(width: 153, height: 85)
        Capsule().fill(Color(red: 0.78, green: 0.62, blue: 0.41)).frame(width: 135, height: 67)
        Capsule().stroke(Color(red: 0.68, green: 0.51, blue: 0.31), lineWidth: 1).frame(
          width: 123, height: 56)
      }.rotationEffect(.degrees(-12))
    }
  }
}

private struct UnevenShade: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 0, y: rect.height))
    p.addQuadCurve(
      to: CGPoint(x: rect.width, y: rect.height), control: CGPoint(x: rect.midX, y: -rect.height))
    p.closeSubpath()
    return p
  }
}
