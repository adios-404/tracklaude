public enum SecureRandom {
    /// Cryptographically secure octets (SystemRandomNumberGenerator is backed by the OS CSPRNG).
    public static func octets(count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
    }
}
