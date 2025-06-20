struct LevelMeter: View {
    var level: Float  // Range: 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                Capsule()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
        .animation(.easeOut(duration: 0.05), value: level)
    }
}