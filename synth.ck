// OSC input setup (FaceOSC)
OscIn oscin;
OscMsg msg;
8338 => oscin.port; // Default port for FaceOSC
oscin.addAddress("/gesture/mouth/width"); // Mouth width data
<<< "Listening for OSC messages on port 8338...", "" >>>;

// MIDI input setup
MidiIn midi;
MidiMsg midiMsg;

// Open MIDI device
0 => int device; // Default device ID
if (me.args()) me.arg(0) => Std.atoi => device; // Get device ID from command line if provided
if (!midi.open(device)) me.exit(); // Exit if the device fails to open
<<< "MIDI device opened:", midi.num(), "->", midi.name() >>>;

// Signal chain setup
NRev rev => Pan2 pan => WvOut waveOut => dac;

// Set output file for recording
waveOut.wavFilename("piano_output.wav"); // Set output file for recording
<<< "Recording to file: piano_output.wav" >>>;

// Parameter mapping
0 => int Osc; // Oscillator type: 0=Sin, 1=Tri, 2=Sqr, 3=Saw
1.0 => float volume; // Controlled by FaceOSC
1000.0 => float lpfCutoff; // LPF cutoff
10.0 => float hpfCutoff; // HPF cutoff
0.0 => float reverb; // Reverb
200::ms => dur decay; // Decay

// Oscillator instances
SinOsc sinOsc;
TriOsc triOsc;
SqrOsc sqrOsc;
SawOsc sawOsc;

// Function to connect the current oscillator to the signal chain
fun void connectOscillatorToChain(int oscType, int note, ADSR env) {
    if (oscType == 0) {
        sinOsc => env => LPF lpf => HPF hpf => rev;
        note => Std.mtof => sinOsc.freq; // Set SinOsc frequency
    } else if (oscType == 1) {
        triOsc => env => LPF lpf => HPF hpf => rev;
        note => Std.mtof => triOsc.freq; // Set TriOsc frequency
    } else if (oscType == 2) {
        sqrOsc => env => LPF lpf => HPF hpf => rev;
        note => Std.mtof => sqrOsc.freq; // Set SqrOsc frequency
    } else if (oscType == 3) {
        sawOsc => env => LPF lpf => HPF hpf => rev;
        note => Std.mtof => sawOsc.freq; // Set SawOsc frequency
    }
}

// Map OSC mouth width to volume
fun float mapMouthWidthToVolume(float width) {
    return Math.max(0.0, Math.min(1.0, (width - 10) / (16 - 10))); // [10, 16] -> [0.0, 1.0]
}

// Function to play a note
fun void PlayBeep(int note, int vel) {
    if (vel > 0) { // Note On
        // Create ADSR instance
        ADSR env;
        (10::ms, decay, 0.7, 50::ms) => env.set; // Set ADSR parameters

        // Connect the selected oscillator to the signal chain
        connectOscillatorToChain(Osc, note, env);

        // Set volume
        vel / 127.0 * volume => sinOsc.gain;

        // Set LPF and HPF parameters
        LPF lpf;
        HPF hpf;
        lpfCutoff => lpf.freq;
        hpfCutoff => hpf.freq;
        reverb => rev.mix; // Set reverb

        // Trigger ADSR
        1 => env.keyOn;
        200::ms => now; // Note duration
        1 => env.keyOff; // ADSR release
    }
}

// OSC and MIDI message processing
60::second + now => time endTime; // Set end time for recording (1 minute)
while (now < endTime) {
    // Handle OSC data
    if (oscin.recv(msg)) {
        if (msg.address == "/gesture/mouth/width") {
            // Receive mouth width data from FaceOSC and control volume
            float mouthWidth;
            msg.getFloat(0) => mouthWidth;
            mapMouthWidthToVolume(mouthWidth) => volume;
            <<< "Mouth Width:", mouthWidth, "Volume:", volume >>>;
        }
    }

    // Handle MIDI data
    if (midi.recv(midiMsg)) {
        if (midiMsg.data1 == 176) { // CC message
            if (midiMsg.data2 == 70) { // CC 70: LPF cutoff
                midiMsg.data3 / 127.0 * 900.0 + 100 => lpfCutoff;
                <<< "LPF Cutoff:", lpfCutoff >>>;
            } else if (midiMsg.data2 == 71) { // CC 71: HPF cutoff
                midiMsg.data3 / 127.0 * 990.0 + 10 => hpfCutoff;
                <<< "HPF Cutoff:", hpfCutoff >>>;
            } else if (midiMsg.data2 == 72) { // CC 72: Reverb
                midiMsg.data3 / 127.0 => reverb;
                <<< "Reverb:", reverb >>>;
            } else if (midiMsg.data2 == 73) { // CC 73: Decay
                (midiMsg.data3 / 127.0 * 300::ms) => decay;
                <<< "Decay:", decay >>>;
            }
        }

        // Oscillator selection (Pad)
        if (midiMsg.data1 == 153 && midiMsg.data2 == 40) { 0 => Osc; <<< "Oscillator: SinOsc" >>>; }
        else if (midiMsg.data1 == 153 && midiMsg.data2 == 41) { 1 => Osc; <<< "Oscillator: TriOsc" >>>; }
        else if (midiMsg.data1 == 153 && midiMsg.data2 == 42) { 2 => Osc; <<< "Oscillator: SqrOsc" >>>; }
        else if (midiMsg.data1 == 153 && midiMsg.data2 == 43) { 3 => Osc; <<< "Oscillator: SawOsc" >>>; }

        // Note input (Note On)
        if (midiMsg.data1 == 144 && midiMsg.data3 > 0) {
            spork ~ PlayBeep(midiMsg.data2, midiMsg.data3);
            <<< "Note On:", midiMsg.data2, "Velocity:", midiMsg.data3 >>>;
        }
    }

    // Maintain loop
    5::ms => now;
}

// Stop recording after 1 minute
waveOut.closeFile();
<<< "Recording completed: piano_output.wav" >>>;
me.exit();
