/*
Name: Khushi Jetley
Title: Plastic Minds: A Continuous Neuroplastic Cellular Automation

Concept & Motivation
This project explores neuroplasticity: the brain’s ability to reorganize 
itself through experience, through a continuous cellular automata system 
inspired by SmoothLife. Rather than binary states, each cell holds a 
continuous activation value interpreted as synaptic strength, allowing 
learning, stabilization, and forgetting to emerge gradually over time 
(Puderbaugh & Emmady, 2023). The work is motivated by an interest in visualizing 
learning as a slow, reversible, and experience-dependent process. By reframing 
SmoothLife’s rules in terms of excitation, inhibition, and plasticity, 
the system operates as a metaphor for neural organization rather than 
biological reproduction.

System Behaviour & Long-Term Dynamics

Each cell evaluates activity within a local and a broader neighbourhood, 
corresponding to immediate firing and wider network context. Synaptic 
strength increases, stabilizes, or decays smoothly based on these densities, 
producing self-organizing pathways, persistent structures, and gradual 
pruning. The system remains continuously plastic and does not converge to a 
fixed state; its structure reflects accumulated interaction history rather 
than a predetermined outcome.

Interaction

Mouse click and drag introduce localized stimulation, strengthening pathways 
through repeated interaction, while the spacebar triggers a global weakening 
event that simulates rest or cognitive reset. Because behaviour depends on 
both initial conditions and user input, repeated runs produce distinct 
structural outcomes.

Technical Realization
The system is implemented as a feedback loop using a buffer to store synaptic 
state over time. Neighbourhood densities are computed using smooth radial 
weighting, with sigmoid-based transitions replacing hard thresholds to 
preserve continuous dynamics. Plasticity is introduced gradually through a 
developmental ramp to improve stability and prevent premature global organization.

Reflection

Early versions of the system exhibited rapid saturation, with activity spreading 
too quickly and erasing meaningful structure. Iterative testing revealed that slower 
learning rates and gradual development were essential for preserving localized 
patterns and long-term memory-like behaviour. This process highlighted the 
importance of tuning not only system rules, but the temporal scale at which they 
operate.

Future Extensions

Future directions include separating excitatory and inhibitory populations, 
introducing synaptic fatigue or refractory periods, enabling real-time parameter 
modulation, and encoding interaction history into longer-term memory layers.

AI Usage Disclosure

AI tools (ChatGPT) were used to assist with debugging and refining code commentary. 
In early iterations, the system produced unstable output due to an error in the feedback 
buffer, where iChannel0 was sampled before the buffer was properly initialized, 
resulting in uniform noise and rapid colour saturation across the frame. ChatGPT was 
used to help identify this issue and suggest correcting the buffer setup and sampling
logic. All code was subsequently tested, modified, and fully understood.

Citations
Gazerani, P. (2025). The neuroplastic brain: Current breakthroughs and emerging 
frontiers. Brain Research, 1858, 149643. https://doi.org/10.1016/j.brainres.2025.149643
Puderbaugh, M., & Emmady, P. D. (2023). Neuroplasticity. In StatPearls. StatPearls 
Publishing. https://www.ncbi.nlm.nih.gov/books/NBK557811/

*/

// Utility Functions

// Smooth transition function used instead of hard thresholds.
// This allows changes to happen gradually rather than abruptly.
float sigmoid(float x, float center, float width) {
    return 1.0 / (1.0 + exp(-(x - center) * 4.0 / width));
}

// Simple hash-based randomness used only for initialization.
// This creates a noisy "undeveloped" starting state.
#define RANDOM_SCALE vec4(.1031, .1030, .0973, .1099)
vec4 random4(vec2 p) {
    vec4 p4 = fract(p.xyxy * RANDOM_SCALE);
    p4 += dot(p4, p4.wzxy + 19.19);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

//Main

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    vec2 uv = fragCoord / iResolution.xy;
    // Read previous synaptic state from the buffer.
    // This feedback loop allows the system to evolve over time.
    vec4 A = texture(iChannel0, uv); 
    
    // Inner radius represents very local neural activity.
    // Outer radius captures broader network context.
    float inner_radius = 3.0;
    float outer_radius = 10.0;

// These parameters define when connections strengthen or weaken.
// They were tuned experimentally to balance stability and responsiveness.

    // Birth/strengthening thresholds
    float b1 = 0.26;
    float b2 = 0.34;

    // Death/pruning thresholds
    float d1 = 0.38;
    float d2 = 0.56;

    // Smoothness of transitions
    float a1 = 0.03;
    float a2 = 0.14;

    // Learning rate = neuroplasticity speed
    // Learning rate controls how quickly synaptic strength changes.
    // Lower values slow learning and preserve long-term structure.
    float dt = 0.18;

    // Density Estimation
    // Accumulators for local (inner) and contextual (outer) neural activity
    float inner_sum = 0.0;
    float outer_sum = 0.0;

    // Scan a circular neighbourhood around each cell
    for (float x = -outer_radius; x <= outer_radius; x++) {
        for (float y = -outer_radius; y <= outer_radius; y++) {
            
            // Offset to a neighbouring cell
            vec2 offset = vec2(x, y);
            vec2 texel = offset / iResolution.xy;
            
            // Read neighbouring synaptic strength
            float life = texture(iChannel0, uv + texel).x;

            // Distance from the current cell
            float dist = length(offset);

            // Weight contribution based on proximity to the inner radius
            float inner_w = 1.0 - sigmoid(dist, inner_radius, 1.0);
            
            // Weight contribution based on proximity to the outer radius
            float outer_w = 1.0 - sigmoid(dist, outer_radius, 1.0);

            // Accumulate weighted activity
            inner_sum += life * inner_w;
            outer_sum += life * outer_w;
        }
    }

    // Approximate areas used to normalize neighbourhood activity
    float inner_area = 3.14159 * inner_radius * inner_radius;
    float outer_area = 3.14159 * outer_radius * outer_radius;
    
    // Local firing density within the inner neighbourhood
    float inner_density = inner_sum / inner_area;
    
    // Broader network activity excluding the inner region
    float outer_density = (outer_sum - inner_sum) / (outer_area - inner_area);

    // Neuroplastic Rules 

    // Synapses survive when surrounding activity is neither too low nor too high
    float notLonely   = sigmoid(outer_density, d1, a1);
    float notCrowded  = 1.0 - sigmoid(outer_density, d2, a1);
    float survive     = notLonely * notCrowded;

    // Synapses strengthen when activity falls within a learning window
    float enough      = sigmoid(outer_density, b1, a1);
    float notTooMuch  = 1.0 - sigmoid(outer_density, b2, a1);
    float strengthen = enough * notTooMuch;

    // Inner activity determines whether learning or stability dominates
    float context = sigmoid(inner_density, 0.5, a2);
    float transition = mix(strengthen, survive, context);

    // Map the transition into a signed change (growth vs pruning)
    float delta = transition * 2.0 - 1.0;

    // Apply gradual plasticity
    A.x += dt * delta;

    // Interaction 

    /// Mouse interaction injects localized stimulation.
    // Repeated input in the same region reinforces pathways over time.
    if (iMouse.z > 0.0) {
        float d = distance(fragCoord, iMouse.xy);
        A.x += exp(-d * 0.06) * 0.4;
    }

    // Spacebar applies a gentle global weakening.
    // This acts as a soft reset rather than erasing structure entirely.
    if (texture(iChannel3, vec2(32.0 / 256.0, 0.0)).r > 0.5) {
        A.x *= 0.85;
    }

    // Clamp for stability
    A = clamp(A, 0.0, 1.0);

    // Initialization (random neural field)
    if (iFrame == 0) {
        A = random4(fragCoord).xxxx;
    }

    fragColor = A;
}
