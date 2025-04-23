// HID setup
Hid hi;
HidMsg keyMsg;

// Try to open the first keyboard device
if (!hi.openKeyboard(0)) {
    <<< "Error: Could not open keyboard device.", "" >>>;
    me.exit();
} else {
    <<< "Keyboard '" + hi.name() + "' ready", "" >>>;
}

// OSC setup
OscIn oscin;
OscMsg oscMsg;
8338 => oscin.port; // FaceOSC default port
oscin.addAddress("/gesture/mouth/width");

<<< "Listening for OSC message from FaceOSC on port 8338...", "" >>>;
<<< " |- expecting \"/gesture/mouth/width\" with 1 continuous parameter...", "" >>>;

// Drum sounds setup with LPF
SndBuf kick => LPF kickLpf => dac;
SndBuf snare => LPF snareLpf => dac;
SndBuf cHat => LPF cHatLpf => dac;
SndBuf oHat => LPF oHatLpf => dac;

// Load drum samples
"/Users/macbookpro/Desktop/kick.wav" => kick.read;
"/Users/macbookpro/Desktop/snare.wav" => snare.read;
"/Users/macbookpro/Desktop/c-hat.wav" => cHat.read;
"/Users/macbookpro/Desktop/o-hat.wav" => oHat.read;

// Initial settings
0.5 => float drumGain; // Initial gain
1000 => float kickCutoff; // Kick LPF cutoff
1000 => float snareCutoff; // Snare LPF cutoff
1000 => float cHatCutoff; // Closed Hat LPF cutoff
1000 => float oHatCutoff; // Open Hat LPF cutoff


// Ensure valid cutoff range
fun float ensureValidCutoff(float cutoff) {
    return Math.max(20.0, Math.min(20000.0, cutoff)); // Ensure cutoff is between 20 Hz and 20,000 Hz
}

// Function to update cutoff and log changes
fun void UpdateCutoff(string name, float newCutoff, LPF filter)
{
    newCutoff => filter.freq;
    <<< "[Cutoff Updated]", name, ":", newCutoff >>>;
}

// Map the input value to a 0-1 range
fun float mapInput(float width, float min, float max)
{
    return Math.max(0.0, Math.min(1.0, (width - min) / (max - min)));
}

// Function to play a specific drum sound with dynamic gain and LPF
fun void PlayDrum(int drumType)
{
    if (drumType == 0) {
        0 => kick.pos;
        drumGain => kick.gain;
        kickCutoff => kickLpf.freq;
    } // Kick
    else if (drumType == 1) {
        0 => snare.pos;
        drumGain => snare.gain;
        snareCutoff => snareLpf.freq;
    } // Snare
    else if (drumType == 2) {
        0 => cHat.pos;
        drumGain => cHat.gain;
        cHatCutoff => cHatLpf.freq;
    } // Closed Hat
    else if (drumType == 3) {
        0 => oHat.pos;
        drumGain => oHat.gain;
        oHatCutoff => oHatLpf.freq;
    } // Open Hat
    100::ms => now; // Allow the sound to play
}

// Sporked function to handle OSC input for gain adjustment
spork ~ HandleOSCInput();

// Function to process OSC input for gain adjustment
fun void HandleOSCInput()
{
    while (true)
    {
        oscin => now; // Wait for OSC input
        
        // Process received OSC messages
        while (oscin.recv(oscMsg))
        {
            // Retrieve the mouth width parameter
            float mouthWidth;
            oscMsg.getFloat(0) => mouthWidth;
            
            // Map mouth width to gain range (0-1)
            mapInput(mouthWidth, 10, 16) => drumGain;
            
            // Debugging: Print the mapped gain
            <<< "Mouth width:", mouthWidth, "Mapped gain:", drumGain >>>;
        }
        
        // Short delay to keep the loop active
        5::ms => now;
    }
}

// Main loop to process keyboard input
while (true)
{
    hi => now; // Wait for keyboard input
    
    // Process received HID messages
    while (hi.recv(keyMsg))
    {
        if (keyMsg.isButtonDown())
        {
            // Drum sound keys
            if (keyMsg.ascii == 81) { PlayDrum(0); } // 'q' -> Kick
            else if (keyMsg.ascii == 87) { PlayDrum(1); } // 'w' -> Snare
            else if (keyMsg.ascii == 69) { PlayDrum(2); } // 'e' -> Closed Hat
            else if (keyMsg.ascii == 82) { PlayDrum(3); } // 'r' -> Open Hat

            // Kick LPF control: 'a' -> Increase, 'z' -> Decrease
            else if (keyMsg.ascii == 65) { ensureValidCutoff(kickCutoff + 100) => kickCutoff; UpdateCutoff("Kick", kickCutoff, kickLpf); }
            else if (keyMsg.ascii == 90) { ensureValidCutoff(kickCutoff - 100) => kickCutoff; UpdateCutoff("Kick", kickCutoff, kickLpf); }
            
            // Snare LPF control: 's' -> Increase, 'x' -> Decrease
            else if (keyMsg.ascii == 83) { ensureValidCutoff(snareCutoff + 100) => snareCutoff; UpdateCutoff("Snare", snareCutoff, snareLpf); }
            else if (keyMsg.ascii == 88) { ensureValidCutoff(snareCutoff - 100) => snareCutoff; UpdateCutoff("Snare", snareCutoff, snareLpf); }
            
            // Closed Hat LPF control: 'd' -> Increase, 'c' -> Decrease
            else if (keyMsg.ascii == 68) { ensureValidCutoff(cHatCutoff + 100) => cHatCutoff; UpdateCutoff("Closed Hat", cHatCutoff, cHatLpf); }
            else if (keyMsg.ascii == 67) { ensureValidCutoff(cHatCutoff - 100) => cHatCutoff; UpdateCutoff("Closed Hat", cHatCutoff, cHatLpf); }
            
            // Open Hat LPF control: 'f' -> Increase, 'v' -> Decrease
            else if (keyMsg.ascii == 70) { ensureValidCutoff(oHatCutoff + 100) => oHatCutoff; UpdateCutoff("Open Hat", oHatCutoff, oHatLpf); }
            else if (keyMsg.ascii == 86) { ensureValidCutoff(oHatCutoff - 100) => oHatCutoff; UpdateCutoff("Open Hat", oHatCutoff, oHatLpf); }
        }
    }
} 