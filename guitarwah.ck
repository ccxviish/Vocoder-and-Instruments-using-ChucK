// Path to the input WAV file
"/Users/macbookpro/Downloads/closetoyou_original.wav" => string inputPath;

// Setup audio processing chain
SndBuf buffer => BiQuad wah => WvOut waveOut => dac => blackhole;

// Set WvOut file name to "closetoyouwah.wav"
waveOut.wavFilename("closetoyouwah.wav");

// Wah-Wah parameters
500 => float minFreq;       // Minimum frequency in Hz
3000 => float maxFreq;      // Maximum frequency in Hz
2000 => float wahRate;      // Wah frequency sweep rate (Hz/s)
0.1 => float damp;          // Damping factor

// Load the input WAV file
<<< "Loading input WAV file:", inputPath >>>;
inputPath => buffer.read;

if (buffer.samples() == 0)
{
    <<< "Error: Could not load WAV file:", inputPath >>>;
    me.exit();
}

// Configure playback volume
0.8 => buffer.gain;

// Wah-Wah filter setup
2 * Math.PI * minFreq / 44100.0 => wah.pfreq; // Initial frequency
damp => wah.prad;                            // Damping factor
0.05 => wah.gain;                            // Filter gain

// Spork a thread to update the Wah-Wah filter dynamically
spork ~ updateWah(wah);

// Function to update the Wah-Wah filter dynamically
fun void updateWah(BiQuad wah)
{
    // Calculate frequency step per sample
    wahRate / 44100.0 => float deltaFreq;
    minFreq => float currentFreq;

    while (true)
    {
        // Update the Wah-Wah filter frequency
        (2 * Math.PI * currentFreq / 44100.0) => wah.pfreq;

        // Adjust frequency for the next update
        currentFreq + deltaFreq => currentFreq;

        // Reverse direction if limits are hit
        if (currentFreq > maxFreq || currentFreq < minFreq)
        {
            -deltaFreq => deltaFreq;
        }

        // Advance time to keep updating
        5::ms => now;
    }
}

// Start processing the buffer
buffer.pos(0);
<<< "Processing with Wah-Wah effect and saving to: closetoyouwah.wav" >>>;

while (buffer.pos() < buffer.samples())
{
    1::samp => now; // Process samples in real-time
}

<<< "Processing completed. Output saved to: closetoyouwah.wav" >>>;
