package
{
  import flash.external.ExternalInterface;
  import flash.display.*;
  import flash.events.Event;
  import flash.events.NetStatusEvent;
  import flash.events.StageVideoAvailabilityEvent;
  import flash.geom.Rectangle;
  import flash.media.StageVideoAvailability;
  import flash.media.StageVideo;
  import flash.media.SoundTransform;
  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;

  public class Player extends MovieClip {
    private var _video:Video;
    private var _stageVideo:StageVideo;
    private var _ns:NetStream;
    private var _nc:NetConnection;
    private var totalTime:Number;
    private var playbackState:String;
    private var videoVolumeTransform:SoundTransform;

    public function Player() {
      playbackState = "IDLE";
      setupNetConnection();
      setupNetStream();
      setupStage();
      setupCallbacks();
      _video = new Video();
    }
    private function setupStage():void {
      stage.scaleMode = StageScaleMode.NO_SCALE;
      stage.align = StageAlign.TOP_LEFT;
      stage.fullScreenSourceRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
      stage.displayState = StageDisplayState.NORMAL;
      stage.addEventListener(StageVideoAvailabilityEvent.STAGE_VIDEO_AVAILABILITY, _onStageVideoAvailability);
      stage.addEventListener(Event.RESIZE, _onResize);
    }
    private function setupNetConnection():void {
      _nc = new NetConnection();
      _nc.connect(null);
    }
    private function setupNetStream():void {
      videoVolumeTransform = new SoundTransform();
      videoVolumeTransform.volume = 1;
      _ns = new NetStream(_nc);
      _ns.client = this;
      _ns.soundTransform = videoVolumeTransform;
      _ns.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
      _ns.bufferTime = 4;
      _ns.inBufferSeek = true;
      _ns.maxPauseBufferTime = 3600;
    }
    private function setupCallbacks():void {
      ExternalInterface.addCallback("getInfos", getInfos);
      ExternalInterface.addCallback("setVideoSize", setVideoSize);
      ExternalInterface.addCallback("playerPlay", playerPlay);
      ExternalInterface.addCallback("playerPause", playerPause);
      ExternalInterface.addCallback("playerStop", playerStop);
      ExternalInterface.addCallback("playerSeek", playerSeek);
      ExternalInterface.addCallback("playerVolume", playerVolume);
      ExternalInterface.addCallback("playerResume", playerResume);
      ExternalInterface.addCallback("getState", getState);
      ExternalInterface.addCallback("getPosition", getPosition);
      ExternalInterface.addCallback("getDuration", getDuration);
    }
    private function netStatusHandler(event:NetStatusEvent):void {
      if (event.info.code === "NetStream.Play.Start" || event.info.code === "NetStream.Buffer.Full") {
        playbackState = "PLAYING";
      } else if (event.info.code === "NetStream.Buffer.Empty" || event.info.code == "NetStream.SeekStart.Notify") {
        playbackState = "PLAYING_BUFFERING";
      } else if (event.info.code == "NetStream.Video.DimensionChange") {
        setVideoSize(stage.stageWidth, stage.stageHeight);
      } else {
        ExternalInterface.call("console.log", event.info.code);
      }
    }
    private function _onResize(event:Event):void {
      setVideoSize(stage.stageWidth, stage.stageHeight);
    }
    private function playerPlay(url:String):void {
      _ns.play(url);
    }
    private function playerPause():void {
      _ns.pause();
    }
    private function playerStop():void {
      _ns.pause();
      _ns.seek(0);
      playbackState = "IDLE";
    }
    private function playerSeek(position:Number):void {
      _ns.seek(position);
    }
    private function playerResume():void {
      _ns.resume();
    }
    private function playerVolume(level:Number):void {
      videoVolumeTransform.volume = level/100;
      _ns.soundTransform = videoVolumeTransform;
    }
    private function getState():String {
      return playbackState;
    }
    private function getPosition():Number {
      return _ns.time;
    }
    private function getDuration():Number {
      return totalTime;
    }
    private function setVideoSize(width:Number, height:Number):void {
      stage.fullScreenSourceRect = new Rectangle(0, 0, width, height);
      var rect:Rectangle = new Rectangle(0,0, width, height);// resizeRectangle(stage.stageWidth, stage.stageHeight, width, height);
      _video.width = rect.width;
      _video.height = rect.height;
      _video.x = rect.x;
      _video.y = rect.y;
      _stageVideo.viewPort = rect;
    }
    public static function resizeRectangle(videoWidth : Number, videoHeight : Number, containerWidth : Number, containerHeight : Number) : Rectangle {
      var rect : Rectangle = new Rectangle();
      var xscale : Number = containerWidth / videoWidth;
      var yscale : Number = containerHeight / videoHeight;
      if (xscale >= yscale) {
          rect.width = Math.min(videoWidth * yscale, containerWidth);
          rect.height = videoHeight * yscale;
      } else {
          rect.width = Math.min(videoWidth * xscale, containerWidth);
          rect.height = videoHeight * xscale;
      }
      rect.width = Math.ceil(rect.width);
      rect.height = Math.ceil(rect.height);
      rect.x = Math.round((containerWidth - rect.width) / 2);
      rect.y = Math.round((containerHeight - rect.height) / 2);
      return rect;
    }
    private function _enableStageVideo():void {
      if (_stageVideo == null) {
        _stageVideo = stage.stageVideos[0];
        _stageVideo.viewPort = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
      }
      if (_video.parent) {
          removeChild(_video);
      }
      _stageVideo.attachNetStream(_ns);
    }
    private function _disableStageVideo():void {
      _video.attachNetStream(_ns);
      addChild(_video);
    }
    private function _onStageVideoAvailability(evt:StageVideoAvailabilityEvent):void {
      if (evt.availability) {
        _enableStageVideo();
      } else {
        _disableStageVideo();
      }
    }
    public function onMetaData(info:Object):void {
      totalTime = info.duration;
    }
  }
}