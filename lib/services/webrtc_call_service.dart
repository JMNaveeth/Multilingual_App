import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcCallService {
  final bool isVideoCall;
  final Future<void> Function(Map<String, dynamic> candidate) onLocalCandidate;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  bool _micEnabled = true;
  bool _cameraEnabled = true;

  WebRtcCallService({
    required this.isVideoCall,
    required this.onLocalCandidate,
  });

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': isVideoCall,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      final rawCandidate = candidate.candidate;
      if (rawCandidate == null || rawCandidate.isEmpty) {
        return;
      }

      onLocalCandidate({
        'candidate': rawCandidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer(<String, dynamic>{});
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer(<String, dynamic>{});
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(Map<String, dynamic> sdp) async {
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(
        sdp['sdp']?.toString() ?? '',
        sdp['type']?.toString() ?? 'offer',
      ),
    );
  }

  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    final rawCandidate = candidate['candidate']?.toString();
    if (rawCandidate == null || rawCandidate.isEmpty) {
      return;
    }

    await _peerConnection!.addCandidate(
      RTCIceCandidate(
        rawCandidate,
        candidate['sdpMid']?.toString(),
        candidate['sdpMLineIndex'] as int?,
      ),
    );
  }

  Future<void> toggleMic() async {
    _micEnabled = !_micEnabled;
    for (final track
        in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = _micEnabled;
    }
  }

  Future<void> toggleCamera() async {
    if (!isVideoCall) {
      return;
    }

    _cameraEnabled = !_cameraEnabled;
    for (final track
        in _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = _cameraEnabled;
    }
  }

  bool get micEnabled => _micEnabled;
  bool get cameraEnabled => _cameraEnabled;
  bool get hasRemoteVideo => remoteRenderer.srcObject != null;

  Future<void> close() async {
    await _peerConnection?.close();
    _peerConnection = null;

    for (final track
        in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }

    await _localStream?.dispose();
    _localStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
