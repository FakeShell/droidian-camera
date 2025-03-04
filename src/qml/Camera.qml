// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

import QtQuick 2.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0
import QtMultimedia 5.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import ZXing 1.0


Item {
    id: cameraItem
    width: 400
    height: 800

    property alias cam: camGst

    function gcd(a, b) {
        if (b == 0) {
            return a;
        } else {
            return gcd(b, a % b);
        }
    }

    function fnAspectRatio() {
        var maxResolution = {width: 0, height: 0};
        var new43 = 0;
        var new169 = 0;

        for (var p in camera.imageCapture.supportedResolutions) {
            var res = camera.imageCapture.supportedResolutions[p];

            var gcdValue = gcd(res.width, res.height);
            var aspectRatio = (res.width / gcdValue) + ":" + (res.height / gcdValue);

            if (res.width * res.height > maxResolution.width * maxResolution.height) {
                maxResolution = res;
            }

            if (aspectRatio === "4:3" && !new43) {
                new43 = 1;
                camera.firstFourThreeResolution = res;
            }

            if (aspectRatio === "16:9" && !new169) {
                new169 = 1;
                camera.firstSixteenNineResolution = res;
            }
        }

        if (camera.aspWide && camera.firstSixteenNineResolution != undefined) {
            camera.imageCapture.resolution = camera.firstSixteenNineResolution;
        } else {
            if (camera.firstFourThreeResolution != undefined) {
                camera.imageCapture.resolution = camera.firstFourThreeResolution
            }
        }

        if (settings.cameras[camera.deviceId] && settings.cameras[camera.deviceId].resolution !== undefined && camera.imageCapture.supportedResolutions[0] != undefined) {
            settings.cameras[camera.deviceId].resolution = Math.round(
                (camera.imageCapture.supportedResolutions[0].width * camera.imageCapture.supportedResolutions[0].height) / 1000000
            );
        }
    }

    function handleSetFlashState(flashState) {
        camera.flash.mode = flashState;
    }

    function handleCameraTakeShot() {
        pinchArea.enabled = true
        camera.imageCapture.capture()
    }

    function handleCameraTakeVideo() {
        handleVideoRecording()
    }

    function handleCameraChangeResolution(resolution) {
        if (camera !== null) {
            if (resolution == "4:3") {
                camera.imageCapture.resolution = camera.firstFourThreeResolution
            }
            else if (resolution == "16:9") {
                camera.imageCapture.resolution = camera.firstSixteenNineResolution
            }
        }
    }

    function handleStopCamera() {
        if (camera !== null && camera !== undefined) {
            camera.stop();
            cameraLoader.active = false;
        }
    }

    function handleStartCamera() {
        camera.start();
    }

    function handleSetFocusMode(focusMode) {
        camera.focus.focusMode = focusMode;
    }

    function handleSetFocusPointMode(focusPointMode) {
        camera.focus.focusPointMode = focusPointMode;
    }

    function handleSetCameraAspWide(aspWide) {
        if (camera !== null) {
            camera.aspWide = aspWide;
        }
    }

    function handleSetDeviceID(deviceIdToSet) {
        camera.deviceId = deviceIdToSet
        settings.deviceId = deviceIdToSet
    }

    function initializeCameraList() {
        var blacklist = []

        if (settingsCommon.blacklist !== "") {
            blacklist = settingsCommon.blacklist.split(',');
        }

        allCamerasModel.clear();

        for (var i = 0; i < QtMultimedia.availableCameras.length; i++) {
            var cameraInfo = QtMultimedia.availableCameras[i];
            var isBlacklisted = false;

            for (var p in blacklist) {
                if (blacklist[p] == cameraInfo.deviceId) {
                    console.log("Camera with the id:", blacklist[p], "is blacklisted, not adding to camera list!");
                    isBlacklisted = true;
                    break;
                }
            }

            if (isBlacklisted) {
                continue;
            }

            if (cameraInfo.position === Camera.BackFace) {
                allCamerasModel.append({"cameraId": cameraInfo.deviceId, "index": i, "position": cameraInfo.position});
                window.backCameras += 1;
            } else if (cameraInfo.position === Camera.FrontFace) {
                allCamerasModel.insert(0, {"cameraId": cameraInfo.deviceId, "index": i, "position": cameraInfo.position});
                window.frontCameras += 1;
            }
        }
    }

    Camera {
        id: camera
        objectName: "camera"
        captureMode: Camera.CaptureStillImage

        property variant firstFourThreeResolution
        property variant firstSixteenNineResolution
        property var aspWide: 0

        position: settings.cameraPosition

        deviceId: settings.cameraId

        focus {
            focusMode: settings.focusMode
            focusPointMode: settings.focusPointMode
        }

        imageProcessing {
            denoisingLevel: 1.0
            sharpeningLevel: 1.0
            whiteBalanceMode: CameraImageProcessing.WhiteBalanceAuto
        }

        flash {
            mode: settings.flashMode
        }

        imageCapture {
            onImageCaptured: {
                if (settings.soundOn === 1) {
                    sound.play()
                }

                if (mediaView.index < 0) {
                    mediaView.folder = StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/furios-camera"
                }
            }

            onImageSaved: {
                if (window.locationAvailable === 1 ) {
                    fileManager.appendGPSMetadata(path);
                }
            }
        }

        Component.onCompleted: {
            camera.stop()
            var currentCam = settings.cameraId
            for (var i = 0; i < QtMultimedia.availableCameras.length; i++) {
                if (settings.cameras[i].resolution == 0)
                    camera.deviceId = i
            }

            if (settings.aspWide == 1 || settings.aspWide == 0) {
                camera.aspWide = settings.aspWide
            }

            cameraItem.fnAspectRatio()

            camera.deviceId = currentCam
            camera.start()

            settings.cameraPosition = camera.position
        }

        onCameraStatusChanged: {
            if (camera.cameraStatus == Camera.LoadedStatus) {
                cameraItem.fnAspectRatio()
            } else if (camera.cameraStatus == Camera.ActiveStatus) {
                focusState.state = "Default"
                camera.focus.focusMode = Camera.FocusContinuous
                camera.focus.focusPointMode = Camera.FocusPointCenter
            }
        }

        onDeviceIdChanged: {
            settings.setValue("cameraId", deviceId);
        }

        onAspWideChanged: {
            settings.setValue("aspWide", aspWide);
        }

        onPositionChanged: {
            settings.cameraId = deviceId
        }
    }

    VideoOutput {
        id: viewfinder

        property var gcdValue: gcd(camera.viewfinder.resolution.width, camera.viewfinder.resolution.height)

        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        anchors.verticalCenterOffset: gcdValue === "16:9" ? -30 * window.scalingRatio : -60 * window.scalingRatio
        source: camera
        autoOrientation: true
        filters: cslate.state === "PhotoCapture" ? [qrCodeComponent.qrcode] : []

        PinchArea {
            id: pinchArea
            x: parent.width / 2 - parent.contentRect.width / 2
            y: parent.height / 2 - parent.contentRect.height / 2
            width: parent.contentRect.width
            height: parent.contentRect.height
            pinch.target: camZoom
            pinch.maximumScale: camera.maximumDigitalZoom / camZoom.zoomFactor
            pinch.minimumScale: 0
            enabled: !mediaView.visible && !window.videoCaptured

            MouseArea {
                id: dragArea
                hoverEnabled: true
                anchors.fill: parent
                enabled: !mediaView.visible && !window.videoCaptured
                property real startX: 0
                property real startY: 0
                property int swipeThreshold: 80
                property var lastTapTime: 0
                property int doubleTapInterval: 300

                onPressed: {
                    startX = mouse.x
                    startY = mouse.y
                }

                onReleased: {
                    var deltaX = mouse.x - startX
                    var deltaY = mouse.y - startY

                    var currentTime = new Date().getTime();
                    if (currentTime - lastTapTime < doubleTapInterval) {
                        window.blurView = 1;
                        settings.cameraPosition = camera.position === Camera.BackFace ? Camera.FrontFace : Camera.BackFace;
                        settings.flashMode = camera.position === Camera.FrontFace ? Camera.FlashOff : settings.flashMode;
                        cameraSwitchDelay.start();
                        lastTapTime = 0;
                    } else {
                        lastTapTime = currentTime;
                        if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > swipeThreshold) {
                            if (deltaY > 0) { // Swipe down logic
                                configBarDrawer.open()
                            } else { // Swipe up logic
                                window.blurView = 1;
                                settings.flashMode= Camera.FlashOff
                                settings.cameraPosition = camera.position === Camera.BackFace ? Camera.FrontFace : Camera.BackFace;
                                settings.flashMode = camera.position === Camera.FrontFace ? Camera.FlashOff : settings.flashMode;
                                cameraSwitchDelay.start();
                            }
                        } else if (Math.abs(deltaX) > swipeThreshold) {
                            if (deltaX > 0) { // Swipe right
                                window.blurView = 1
                                window.swipeDirection = 0
                                swappingDelay.start()
                            } else { // Swipe left
                                window.blurView = 1
                                window.swipeDirection = 1
                                swappingDelay.start()
                            }
                        } else { // Touch
                            var relativePoint;

                            switch (viewfinder.orientation) {
                                case 0:
                                    relativePoint = Qt.point(mouse.x / viewfinder.contentRect.width, mouse.y / viewfinder.contentRect.height)
                                    break
                                case 90:
                                    relativePoint = Qt.point(1 - (mouse.y / viewfinder.contentRect.height), mouse.x / viewfinder.contentRect.width)
                                    break
                                case 180:
                                    absolutePoint = Qt.point(1 - (mouse.x / viewfinder.contentRect.width), 1 - (mouse.y / viewfinder.contentRect.height))
                                    break
                                case 270:
                                    relativePoint = Qt.point(mouse.y / viewfinder.contentRect.height, 1 - (mouse.x / viewfinder.contentRect.width))
                                    break
                                default:
                                    console.error("wtf")
                            }

                            if (aefLockTimer.running) {
                                focusState.state = "TargetLocked"
                                aefLockTimer.stop()
                            } else {
                                focusState.state = "AutomaticFocus"
                                window.aeflock = "AEFLockOff"
                            }

                            if (window.aeflock !== "AEFLockOn" || focusState.state === "TargetLocked") {
                                camera.focus.customFocusPoint = relativePoint
                                focusPointRect.width = 60 * window.scalingRatio
                                focusPointRect.height = 60 * window.scalingRatio
                                window.focusPointVisible = true
                                focusPointRect.x = mouse.x - (focusPointRect.width / 2)
                                focusPointRect.y = mouse.y - (focusPointRect.height / 2)
                            }

                            window.blurView = 0
                            configBarDrawer.close()
                            optionContainer.state = "closed"
                            visTm.start()
                        }
                    }
                }
            }

            onPinchUpdated: {
                camZoom.zoom = pinch.scale * camZoom.zoomFactor
            }

            Rectangle {
                id: focusPointRect
                border {
                    width: 2
                    color: "#FDD017"
                }

                color: "transparent"
                radius: 5 * window.scalingRatio
                width: 80 * window.scalingRatio
                height: 80 * window.scalingRatio
                visible: window.focusPointVisible

                Timer {
                    id: visTm
                    interval: 500; running: false; repeat: false
                    onTriggered: window.aeflock === "AEFLockOff" ? window.focusPointVisible = false : null
                }
            }
        }

        QrCode {
            id: qrCodeComponent
            viewfinder: viewfinder
            openPopupFunction: openPopup
        }

        Rectangle {
            anchors.fill: parent
            opacity: blurView ? 1 : 0
            color: "#40000000"
            visible: opacity != 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }
    }

    MediaPlayer {
        id: camGst
        autoPlay: false
        videoOutput: viewfinder
        property var backendId: 0
        property string outputPath: StandardPaths.writableLocation(StandardPaths.MoviesLocation).toString().replace("file://","") +
                                            "/furios-camera/video" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmsszzz") + ".mkv"

        property var backends: [
            {
                front: "gst-pipeline: droidcamsrc mode=2 camera-device=1 ! video/x-raw ! videoconvert ! qtvideosink",
                frontRecord: "gst-pipeline: droidcamsrc camera_device=1 mode=2 ! tee name=t t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! videoflip video-direction=2 ! qtvideosink t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! videoflip video-direction=auto ! jpegenc ! mkv. autoaudiosrc ! queue ! audioconvert ! droidaenc ! mkv. matroskamux name=mkv ! filesink location=" + outputPath,
                back: "gst-pipeline: droidcamsrc mode=2 camera-device=" + camera.deviceId + " ! video/x-raw ! videoconvert ! qtvideosink",
                backRecord: "gst-pipeline: droidcamsrc camera_device=" + camera.deviceId + " mode=2 ! tee name=t t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! qtvideosink t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! videoflip video-direction=auto ! jpegenc ! mkv. autoaudiosrc ! queue ! audioconvert ! droidaenc ! mkv. matroskamux name=mkv ! filesink location=" + outputPath
            }
        ]

        onError: {
            if (backendId + 1 in backends) {
                backendId++;
            }
        }
    }

    function handleVideoRecording() {
        if (window.videoCaptured == false) {
            camGst.outputPath = StandardPaths.writableLocation(StandardPaths.MoviesLocation).toString().replace("file://","") +
                                            "/furios-camera/video" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmsszzz") + ".mkv"

            if (camera.position === Camera.BackFace) {
                camGst.source = camGst.backends[camGst.backendId].backRecord;
            } else {
                camGst.source = camGst.backends[camGst.backendId].frontRecord;
            }

            camera.stop();

            camGst.play();
            window.videoCaptured = true;
        } else {
            camGst.stop();
            window.videoCaptured = false;
            camera.cameraState = Camera.UnloadedState;
            camera.start();
        }
    }

    Item {
        id: camZoom
        property real zoomFactor: 2.0
        property real zoom: 0
        NumberAnimation on zoom {
            duration: 200
            easing.type: Easing.InOutQuad
        }

        onScaleChanged: {
            camera.setDigitalZoom(scale * zoomFactor)
        }
    }

    FastBlur {
        id: vBlur
        anchors.fill: parent
        opacity: blurView ? 1 : 0
        source: viewfinder
        radius: 128
        visible: opacity != 0
        transparentBorder: false
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }

    Glow {
        anchors.fill: vBlur
        opacity: blurView ? 1 : 0
        radius: 4
        samples: 1
        color: "black"
        source: vBlur
        visible: opacity != 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }
}
