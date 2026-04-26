//
//  RippleMetal.metal
//  RippleTransitions
//
//  Created by Balaji Venkatesh on 22/02/25.
//

/// In WWDC 24, Apple showcased a tutorial demonstrating the usage of the Ripple Metal Shader Effect. I customized the tutorial to meet my specific requirements, which is to achieve a bounce effect without altering the pixel colors.
/// For more information, please refer to the provided link 👇
/// https://developer.apple.com/videos/play/wwdc2024/10151/

#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 Ripple(float2 position, SwiftUI::Layer layer, float2 origin,
    float time, float amplitude, float frequency, float decay, float speed) {
    
    float distance = length(position - origin);
    float delay = distance / speed;

    time -= delay;
    time = max(0.0, time);

    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);

    float2 n = normalize(position - origin);

    float2 newPosition = position + rippleAmount * n;

    half4 color = layer.sample(newPosition);
    
    return color;
}
