import AVFoundation
import Foundation

extension ReelRenderer {
    static let minimumMusicSeconds = 1.0
    static let musicVolumeWithoutVoice: Float = 0.6

    static func mix(video: URL, voice: URL?, music: URL?, to target: URL) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        guard let source = try await videoAsset.loadTracks(withMediaType: .video).first,
            let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw Problem(message: "no se pudo leer el video para ponerle el sonido")
        }
        let total = try await videoAsset.load(.duration)
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: total), of: source, at: .zero)
        if let voice {
            try await addVoice(voice, to: composition, lasting: total)
        }
        var parameters: [AVMutableAudioMixInputParameters] = []
        if let music, let volume = try await addMusic(music, to: composition, lasting: total, withVoice: voice != nil) {
            parameters.append(volume)
        }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Problem(message: "no se pudo preparar la exportación del video")
        }
        if !parameters.isEmpty {
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = parameters
            export.audioMix = audioMix
        }
        try await export.export(to: target, as: .mp4)
    }

    static func addVoice(_ voice: URL, to composition: AVMutableComposition, lasting total: CMTime) async throws {
        let asset = AVURLAsset(url: voice)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first,
            let voiceTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return }
        let length = CMTimeMinimum(try await asset.load(.duration), total)
        try? voiceTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: track, at: .zero)
    }

    static func addMusic(
        _ music: URL, to composition: AVMutableComposition, lasting total: CMTime, withVoice: Bool
    ) async throws -> AVMutableAudioMixInputParameters? {
        let asset = AVURLAsset(url: music)
        let duration = try await asset.load(.duration)
        guard duration.seconds > minimumMusicSeconds, let track = try await asset.loadTracks(withMediaType: .audio).first,
            let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return nil }
        var position = CMTime.zero
        while CMTimeCompare(position, total) < 0 {
            let length = CMTimeMinimum(duration, CMTimeSubtract(total, position))
            try? musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: track, at: position)
            position = CMTimeAdd(position, length)
        }
        let volume = AVMutableAudioMixInputParameters(track: musicTrack)
        volume.setVolume(withVoice ? musicVolume : musicVolumeWithoutVoice, at: .zero)
        return volume
    }
}
