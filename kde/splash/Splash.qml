// Nordic's splash in Neon Ninja's style: the same pulsing logo and progress bar, with straight corners.
// build-theme.py adds images/background.jpg and images/logo.png.
import QtQuick

Rectangle {
    id: root
    color: "#050507"

    property int stage

    onStageChanged: {
        if (stage == 1) {
            intro.running = true
        }
    }

    Image {
        anchors.fill: parent
        source: "images/background.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Image {
            id: logo
            anchors.centerIn: parent
            source: "images/logo.png"
            sourceSize: Qt.size(280, 280)

            ParallelAnimation {
                running: true

                ScaleAnimator {
                    target: logo
                    from: 0
                    to: 1
                    duration: 700
                }

                SequentialAnimation {
                    loops: Animation.Infinite

                    ScaleAnimator {
                        target: logo
                        from: 0.97
                        to: 1
                        duration: 1000
                    }
                    ScaleAnimator {
                        target: logo
                        from: 1
                        to: 0.97
                        duration: 1000
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - (parent.height - logo.y) / 3 - height / 2
            width: 320
            height: 4
            color: "#16161d"

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: (parent.width / 6) * (root.stage - 1)
                color: "#ff2e4d"

                Behavior on width {
                    PropertyAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    OpacityAnimator {
        id: intro
        running: false
        target: content
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.InOutQuad
    }
}
