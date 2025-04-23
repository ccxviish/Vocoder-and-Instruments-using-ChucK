// OSC and MIDI configuration
0 => int onOrOff;

// Input
// Synth input
Gain line_synth => FFT fft_synth => blackhole;
// Mic input
adc.left => PoleZero dcblock_mic => FFT fft_mic => blackhole;

// Output
// Declare WvOut for recording
WvOut waveOut;
IFFT ifft_output => PoleZero dcblock_output => PitShift shift => Chorus chorus => LPF filter_lpf => HPF filter_hpf => JCRev reverb => Gain vocoderOutput => waveOut => dac;
// Unprocessed audio (optional; set adcOutput.gain to 0 to mute)
adc => Gain adcOutput => dac;

// Set output file for recording
waveOut.wavFilename("output_vo.wav"); // Set the output file name
<<< "Recording to file: output_vo.wav" >>>;

// MIDI Setup
//---------------------------------------------------------------------
0 => int device;
if (me.args()) me.arg(0) => Std.atoi => device;

MidiIn min;
MidiMsg msg;

if (!min.open(device)) me.exit();
<<< "MIDI device:", min.num(), " -> ", min.name() >>>;
//---------------------------------------------------------------------

// OSC Setup
OscIn oscin;
oscin.port(8338); // Set the port to 8338
oscin.addAddress("/gesture/eye/left"); // Listen for "/gesture/eye/left" message
<<< "Listening for OSC on port 8338..." >>>;

// Declare global variables
float eyeLeftThreshold;
float eyeLeft;
0 => int echoEnabled;

// Initialize variables
fun void initialize() {
    0.2 => eyeLeftThreshold; // Threshold to detect if the eye is closed
    0.0 => eyeLeft;          // Store left eye value from OSC
}
spork ~ initialize();

// Unit Generator Initial Values
0.1 => vocoderOutput.gain;
0.0 => adcOutput.gain;
0.1 => line_synth.gain;
filter_lpf.freq(0.999 * 10000);
filter_hpf.freq(0.001 * 10000);

// Effect Values
shift.mix(1.0);
shift.shift(1.0);
reverb.mix(0.05);
chorus.mix(0.2);
chorus.modDepth(0.0);

// Set Echo Parameters
DelayL echo; // Create the DelayL object for echo effect
0.2 => echo.gain; // Set echo gain
0.6::second => echo.delay; // Set echo delay time

// Remove Zero Frequency Components to Reduce Distortion
0.99999 => dcblock_mic.blockZero;
0.99999 => dcblock_output.blockZero;

// Fast Fourier Transform Constants
512 => int FFT_SIZE => fft_synth.size => fft_mic.size => ifft_output.size;
FFT_SIZE => int WIN_SIZE;
FFT_SIZE / 32 => int HOP_SIZE;

// Define Hann Window for FFT
Windowing.hann(WIN_SIZE) => fft_mic.window => fft_synth.window => ifft_output.window;

// Define Spectrum Arrays
complex spectrum_synth[WIN_SIZE / 2];
complex spectrum_mic[WIN_SIZE / 2];
polar temp_polar_mic, temp_polar_synth;

// Define NoteEvent
class NoteEvent extends Event {
    float note;
}

NoteEvent on;
NoteEvent off;

// FFT Implementation
//--------------------------------------------------------------------
fun void vocode_filter() {
    while (true) {
        // Take mic FFT
        fft_mic.upchuck();
        // Take synth FFT
        fft_synth.upchuck();
        // Retrieve mic spectrum
        fft_mic.spectrum(spectrum_mic);
        // Retrieve synth spectrum
        fft_synth.spectrum(spectrum_synth);

        // Apply mic magnitude to synth spectrum
        for (0 => int i; i < spectrum_mic.cap(); i++) {
            spectrum_mic[i]$polar => temp_polar_mic;
            spectrum_synth[i]$polar => temp_polar_synth;
            temp_polar_mic.mag => temp_polar_synth.mag;
            temp_polar_synth$complex => spectrum_synth[i];
        }
        // Inverse transform of the altered synth spectrum
        ifft_output.transform(spectrum_synth);
        HOP_SIZE::samp => now;
    }
}
spork ~ vocode_filter();
//--------------------------------------------------------------------

// Synthesizer Implementation
//--------------------------------------------------------------------
fun void synthvoice() {
    SqrOsc voice;
    Event off;
    float note;

    while (true) {
        on => now;
        <<< "NoteOn:", msg.data1, msg.data2 >>>;
        on.note => note;
        note => voice.freq;
        0.1 => voice.gain;
        voice => line_synth;

        if (onOrOff == 0) {
            <<< "NoteOff:", msg.data1, msg.data2 >>>;
            0.0 => voice.gain;
            voice =< line_synth;
        }
    }
}

// Run the Specified Iterations of the Synth
for (0 => int i; i < 4; i++) spork ~ synthvoice();
//--------------------------------------------------------------------

// OSC Handling using msg and getFloat for left eye closed detection
fun void process_osc() {
    OscMsg msg;
    while (true) {
        // Receive OSC message
        oscin.recv(msg);

        // Process the "/gesture/eye/left" message and extract the value (eye left)
        // Get the eye left (closed) value from the message
        msg.getFloat(0) => eyeLeft;

        // Print the current eyeLeft value (for debugging)
        <<< "Current left eye value (closed state):", eyeLeft >>>;

        // Control the echo based on eyeLeft value (detect if closed)
        if (eyeLeft < eyeLeftThreshold) { // Eye is closed if value is below threshold
            <<< "Left eye closed: Enabling echo" >>>;
            1 => echoEnabled;
        } else {
            <<< "Left eye open: Disabling echo" >>>;
            0 => echoEnabled;
        }
        // Sleep for 1 second before checking again
        1::second => now;
    }
}
spork ~ process_osc();

// Set the recording duration to 20 seconds (using `dur`)
60::second+now => time endTime; // Use dur type for time comparison

// Main Audio Processing Loop
while (now < endTime) {  // Compare with current time + duration
    // Apply echo effect based on OSC input
    if (echoEnabled) {
        vocoderOutput => echo;
    } else {
        vocoderOutput =< echo;
    }

    // MIDI message handling
    if (min.recv(msg)) {
        if (msg.data1 == 144 && msg.data2 > 0) { // Note On with velocity > 0
            <<< "MIDI Note On:", msg.data1, "Key:", msg.data2 >>>;
        } else if (msg.data1 == 128 || (msg.data1 == 144 && msg.data2 == 0)) { // Note Off
            <<< "MIDI Note Off:", msg.data1, "Key:", msg.data2 >>>;
        }
    }

    10::ms => now; // Small delay to prevent infinite loop from consuming too much CPU
}

// After the specified time (20 seconds), stop recording and close the file
waveOut.closeFile(); // Close the WAV file after recording is complete
<<< "Recording completed after 60 seconds: output_vo.wav" >>>;
me.exit();
