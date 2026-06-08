/// HTML shell for official YouTube Iframe API (mobile WebView + web platform views).
abstract final class YoutubeIframeHtml {
  static String playerPage({
    required String videoId,
    required String elementId,
    bool autoplay = true,
    bool mute = true,
    bool enableIntersectionObserver = false,
    bool showControls = false,
  }) {
    final autoplayJs = autoplay ? '1' : '0';
    final muteJs = mute ? '1' : '0';
    final controlsJs = showControls ? '1' : '0';
    final safeId = _escape(videoId);
    final ioBlock = enableIntersectionObserver
        ? '''
    var wrap = document.getElementById('wrap');
    if (wrap && 'IntersectionObserver' in window) {
      var io = new IntersectionObserver(function(entries) {
        entries.forEach(function(entry) {
          if (!player || !player.playVideo) return;
          if (entry.intersectionRatio >= 0.55) {
            player.playVideo();
          } else {
            player.pauseVideo();
          }
        });
      }, { threshold: [0, 0.55, 1] });
      io.observe(wrap);
    }
'''
        : '';

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body { margin:0; padding:0; width:100%; height:100%; background:#000; overflow:hidden; }
  #wrap {
    position:fixed; inset:0; background:#000; overflow:hidden;
  }
  #$elementId {
    position:absolute;
    inset:0;
    width:100%;
    height:100%;
  }
</style>
</head>
<body>
<div id="wrap"><div id="$elementId"></div></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
  var player = null;
  window.__shortsYT = window.__shortsYT || {};

  function post(msg) {
    try {
      if (window.FlutterChannel && window.FlutterChannel.postMessage) {
        window.FlutterChannel.postMessage(msg);
      }
    } catch (e) {}
  }

  window.playCmd = function() {
    if (player && player.playVideo) player.playVideo();
  };
  window.pauseCmd = function() {
    if (player && player.pauseVideo) player.pauseVideo();
  };
  window.muteCmd = function(shouldMute) {
    if (!player) return;
    if (shouldMute && player.mute) player.mute();
    else if (!shouldMute && player.unMute) player.unMute();
  };

  function onYouTubeIframeAPIReady() {
    player = new YT.Player('$elementId', {
      videoId: '$safeId',
      width: '100%',
      height: '100%',
      playerVars: {
        autoplay: $autoplayJs,
        mute: $muteJs,
        playsinline: 1,
        controls: $controlsJs,
        rel: 0,
        modestbranding: 1,
        fs: 0,
        iv_load_policy: 3,
        enablejsapi: 1,
        origin: window.location.origin || 'https://www.youtube.com'
      },
      events: {
        onReady: function(e) {
          window.__shortsYT['$safeId'] = e.target;
          post('ready');
          if ($autoplayJs) e.target.playVideo();
        },
        onError: function() { post('error'); },
        onStateChange: function(ev) {
          if (ev.data === YT.PlayerState.PLAYING) post('playing');
          if (ev.data === YT.PlayerState.PAUSED) post('paused');
        }
      }
    });
  }

  $ioBlock
</script>
</body>
</html>
''';
  }

  static String _escape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
}
