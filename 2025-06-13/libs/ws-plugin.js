/*
 * Copyright (C) 2024-2025 Amarisoft
 * ws.js nodejs plugin example version 2025-06-13
 */

module.exports = {

    /* Return array of additional arguments to parse
     * always return an array: let it empty if nothing to do
     */
    onInit: function () {
        // Put ws.js in listen mode
        return ['-l' ];
    },

    /* Called on web soccket connection */
    onStart: function () {
        // On connection ready, send echo
        global.sendMsg({message: "echo"});
    },

    onMessage: function (msg) {
        switch (msg.message) {
        case 'echo':
            global.log('Receiving message' , msg.message);
            break;
        default:
            break;
        }
    },

};


