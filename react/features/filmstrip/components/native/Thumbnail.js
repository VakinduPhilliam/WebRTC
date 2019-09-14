// @flow

import React, { Component } from 'react';
import { connect } from 'react-redux';

import { openDialog } from '../../../base/dialog';
import { Audio, MEDIA_TYPE } from '../../../base/media';
import {
    PARTICIPANT_ROLE,
    ParticipantView,
    isLocalParticipantModerator,
    pinParticipant
} from '../../../base/participants';
import { Container } from '../../../base/react';
import { getTrackByMediaTypeAndParticipant } from '../../../base/tracks';

import { RemoteVideoMenu } from '../../../remote-video-menu';

import AudioMutedIndicator from './AudioMutedIndicator';
import DominantSpeakerIndicator from './DominantSpeakerIndicator';
import ModeratorIndicator from './ModeratorIndicator';
import { AVATAR_SIZE } from '../styles';
import styles from './styles';
import VideoMutedIndicator from './VideoMutedIndicator';

/**
 * Thumbnail component's property types.
 */
type Props = {

    /**
     * The Redux representation of the participant's audio track.
     */
    _audioTrack: Object,

    /**
     * True if the local participant is a moderator.
     */
    _isModerator: boolean,

    /**
     * The Redux representation of the state "features/large-video".
     */
    _largeVideo: Object,

    /**
     * Handles click/tap event on the thumbnail.
     */
    _onClick: ?Function,

    /**
     * Handles long press on the thumbnail.
     */
    _onShowRemoteVideoMenu: ?Function,

    /**
     * The Redux representation of the participant's video track.
     */
    _videoTrack: Object,

    /**
     * If true, tapping on the thumbnail will not pin the participant to large
     * video. By default tapping does pin the participant.
     */
    disablePin?: boolean,

    /**
     * If true, there will be no color overlay (tint) on the thumbnail
     * indicating the participant associated with the thumbnail is displayed on
     * large video. By default there will be a tint.
     */
    disableTint?: boolean,

    /**
     * Invoked to trigger state changes in Redux.
     */
    dispatch: Dispatch<*>,

    /**
     * The Redux representation of the participant to display.
     */
    participant: Object,

    /**
     * Optional styling to add or override on the Thumbnail component root.
     */
    styleOverrides?: Object
};

/**
 * React component for video thumbnail.
 *
 * @extends Component
 */
class Thumbnail extends Component<Props> {
    /**
     * Implements React's {@link Component#render()}.
     *
     * @inheritdoc
     * @returns {ReactElement}
     */
    render() {
        const {
            _audioTrack: audioTrack,
            _isModerator,
            _largeVideo: largeVideo,
            _onClick,
            _onShowRemoteVideoMenu,
            _videoTrack: videoTrack,
            disablePin,
            disableTint,
            participant
        } = this.props;

        // We don't render audio in any of the following:
        // 1. The audio (source) is muted. There's no practical reason (that we
        //    know of, anyway) why we'd want to render it given that it's
        //    silence (& not even comfort noise).
        // 2. The audio is local. If we were to render local audio, the local
        //    participants would be hearing themselves.
        const audioMuted = !audioTrack || audioTrack.muted;
        const renderAudio = !audioMuted && !audioTrack.local;
        const participantId = participant.id;
        const participantInLargeVideo
            = participantId === largeVideo.participantId;
        const videoMuted = !videoTrack || videoTrack.muted;
        const showRemoteVideoMenu = _isModerator && !participant.local;

        return (
            <Container
                onClick = { disablePin ? undefined : _onClick }
                onLongPress = {
                    showRemoteVideoMenu
                        ? _onShowRemoteVideoMenu : undefined }
                style = { [
                    styles.thumbnail,
                    participant.pinned && !disablePin
                        ? styles.thumbnailPinned : null,
                    this.props.styleOverrides || null
                ] }
                touchFeedback = { false }>

                { renderAudio
                    && <Audio
                        stream
                            = { audioTrack.jitsiTrack.getOriginalStream() } /> }

                <ParticipantView
                    avatarSize = { AVATAR_SIZE }
                    participantId = { participantId }
                    tintEnabled = { participantInLargeVideo && !disableTint }
                    zOrder = { 1 } />

                { participant.role === PARTICIPANT_ROLE.MODERATOR
                    && <ModeratorIndicator /> }

                { participant.dominantSpeaker
                    && <DominantSpeakerIndicator /> }

                <Container style = { styles.thumbnailIndicatorContainer }>
                    { audioMuted
                        && <AudioMutedIndicator /> }

                    { videoMuted
                        && <VideoMutedIndicator /> }
                </Container>

            </Container>
        );
    }
}

/**
 * Maps part of redux actions to component's props.
 *
 * @param {Function} dispatch - Redux's {@code dispatch} function.
 * @param {Props} ownProps - The own props of the component.
 * @returns {{
 *     _onClick: Function,
 *     _onShowRemoteVideoMenu: Function
 * }}
 */
function _mapDispatchToProps(dispatch: Function, ownProps): Object {
    return {
        /**
         * Handles click/tap event on the thumbnail.
         *
         * @protected
         * @returns {void}
         */
        _onClick() {
            const { participant } = ownProps;

            dispatch(
                pinParticipant(participant.pinned ? null : participant.id));
        },

        /**
         * Handles long press on the thumbnail.
         *
         * @returns {void}
         */
        _onShowRemoteVideoMenu() {
            const { participant } = ownProps;

            dispatch(openDialog(RemoteVideoMenu, {
                participant
            }));
        }
    };
}

/**
 * Function that maps parts of Redux state tree into component props.
 *
 * @param {Object} state - Redux state.
 * @param {Props} ownProps - Properties of component.
 * @returns {{
 *      _audioTrack: Track,
 *      _isModerator: boolean,
 *      _largeVideo: Object,
 *      _videoTrack: Track
 *  }}
 */
function _mapStateToProps(state, ownProps) {
    // We need read-only access to the state of features/large-video so that the
    // filmstrip doesn't render the video of the participant who is rendered on
    // the stage i.e. as a large video.
    const largeVideo = state['features/large-video'];
    const tracks = state['features/base/tracks'];
    const id = ownProps.participant.id;
    const audioTrack
        = getTrackByMediaTypeAndParticipant(tracks, MEDIA_TYPE.AUDIO, id);
    const videoTrack
        = getTrackByMediaTypeAndParticipant(tracks, MEDIA_TYPE.VIDEO, id);

    return {
        _audioTrack: audioTrack,
        _isModerator: isLocalParticipantModerator(state),
        _largeVideo: largeVideo,
        _videoTrack: videoTrack
    };
}

export default connect(_mapStateToProps, _mapDispatchToProps)(Thumbnail);
