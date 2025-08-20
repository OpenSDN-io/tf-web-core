/*
 * Copyright (c) 2016 Juniper Networks, Inc. All rights reserved.
 */
let Threads;
let isModern = false;
try {
    // try to use the worker_threads module available in Node.js 10.5.0 and later
    Threads = require('worker_threads');
    isModern = true;
} catch (e) {
    // Fallback to the webworker-threads module for older Node.js versions
    Threads = require('webworker-threads');
}

/* Function: createWorkerThread
 * public function
 *
 * This function is used to create a thread and run the job in that thread
 * context. Once done, notify the caller.
 *
 * @threadCB    : thread to execute function
 * @data        : data to pass to threadCB
 * @callback    : function to call once threadCB is done.
 */

function runInThread (threadCB, data, callback) {
    /* Create thread */
    var newThread = Threads.create();
    /* Load the function into the worker thread */
    newThread.eval(threadCB);
    /* Now call the function */
    newThread.eval(
        threadCB(data, function(error, data) {
            callback(error, data);
        }), function(error, result) { // eslint-disable-line
            newThread.destroy();
        }
    );
}

function runInThreadModern(threadCB, data, callback) {
    const { Worker } = Threads;

    // Create worker code as a string. It will run in a separate thread.
    const workerCode = `
        const { parentPort, workerData } = require('node:worker_threads');
        // Restore the function that was passed from the main thread
        const fn = (${threadCB.toString()});
        // Execute the function with given data
        fn(workerData, (err, res) => {
            // Send result back to the main thread
            parentPort.postMessage({ err: err ? String(err) : null, res });
        });
    `;

    // Create a new worker from this code (eval means code is given as string)
    const worker = new Worker(workerCode, {
        eval: true,
        workerData: data,  // data is passed to workerData inside worker
    });

    // Listen for the result message from the worker
    worker.on('message', (msg) => {
        // Call the callback provided by the caller
        callback(msg.err ? new Error(msg.err) : null, msg.res);
        // Destroy worker after the work is done
        worker.terminate();
    });

    // If worker fails to start or throws error, report it
    worker.on('error', (err) => {
        callback(err);
    });

    // If worker exits abnormally, report it too
    worker.on('exit', (code) => {
        if (code !== 0) {
            callback(new Error('Worker stopped with exit code ' + code));
        }
    });
}

exports.runInThread = isModern ? runInThreadModern : runInThread;