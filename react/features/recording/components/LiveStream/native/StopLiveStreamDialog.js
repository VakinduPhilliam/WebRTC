// @flow

import React from 'react';
import { connect } from 'react-redux';

import { ConfirmDialog } from '../../../../base/dialog';
import { translate } from '../../../../base/i18n';

import AbstractStopLiveStreamDialog, {
    _mapStateToProps
} from '../AbstractStopLiveStreamDialog';

/**
 * A React Component for confirming the participant wishes to stop the currently
 * active live stream of the conference.
 *
 * @extends Component
 */
class StopLiveStreamDialog extends AbstractStopLiveStreamDialog {

    /**
     * Implements React's {@link Component#render()}.
     *
     * @inheritdoc
     * @returns {ReactElement}
     */
    render() {
        return (
            <ConfirmDialog
                contentKey = 'dialog.stopStreamingWarning'
                onSubmit = { this._onSubmit } />
        );
    }

    _onSubmit: () => boolean
}

export default translate(connect(_mapStateToProps)(StopLiveStreamDialog));
