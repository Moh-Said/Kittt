import AVFoundation
import MediaToolbox
import Observation

@MainActor
@Observable
final class AudioLevelTap {
    private(set) var level: Float = 0

    @ObservationIgnored private var tap: MTAudioProcessingTap?

    func attach(to item: AVPlayerItem) {
        detach()
        Task { [weak self] in
            let tracks = try? await item.asset.loadTracks(withMediaType: .audio)
            guard let self, let track = tracks?.first else { return }
            await MainActor.run {
                self.install(on: item, track: track)
            }
        }
    }

    private func install(on item: AVPlayerItem, track: AVAssetTrack) {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        var outTap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &outTap
        )
        guard status == noErr, let createdTap = outTap else { return }
        tap = createdTap

        let inputParams = AVMutableAudioMixInputParameters(track: track)
        inputParams.audioTapProcessor = createdTap

        let mix = AVMutableAudioMix()
        mix.inputParameters = [inputParams]
        item.audioMix = mix
    }

    func detach() {
        tap = nil
        level = 0
    }

    fileprivate func ingest(rms: Float) {
        let attack: Float = 0.40
        let decay: Float = 0.04
        let coeff: Float = rms > level ? attack : decay
        level = level + (rms - level) * coeff
    }
}

private let tapInit: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
    tapStorageOut.pointee = clientInfo
}

private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { _ in }

private let tapPrepare: MTAudioProcessingTapPrepareCallback = { _, _, _ in }

private let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { _ in }

private let tapProcess: MTAudioProcessingTapProcessCallback = { tap, frames, _, bufferList, framesOut, flagsOut in
    let status = MTAudioProcessingTapGetSourceAudio(tap, frames, bufferList, flagsOut, nil, framesOut)
    guard status == noErr else { return }

    var sumSq: Float = 0
    var count: Int = 0
    let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
    for buf in buffers {
        guard let data = buf.mData?.assumingMemoryBound(to: Float.self) else { continue }
        let n = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
        for i in 0..<n {
            sumSq += data[i] * data[i]
        }
        count += n
    }
    let rms = count > 0 ? sqrt(sumSq / Float(count)) : 0

    let storage = MTAudioProcessingTapGetStorage(tap)
    let owner = Unmanaged<AudioLevelTap>.fromOpaque(storage).takeUnretainedValue()
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            owner.ingest(rms: rms)
        }
    }
}
