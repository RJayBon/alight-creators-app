/// Full seed data mirrored from the web app's MySQL export.
///
/// Passwords are bcrypt-hashed at seed time (see `SeedService`).
/// `preHashedPasswords` lets us store a bcrypt hash that was generated
/// elsewhere (e.g. copied from the web DB) verbatim.
class SeedData {
  /// Plain passwords — hashed with bcrypt on first run.
  static const Map<String, String> plainPasswords = {
    'admin@alight.local': 'AlightAdmin2026',
    'minutemotion@gmail.com': 'password123',
    'rjayon43@gmail.com': 'password123',
    'wizzytuts@gmail.com': 'password123',
    'lokipoki@gmail.com': 'password123',
  };

  /// If an email appears here, the seeder stores this exact bcrypt hash
  /// verbatim instead of hashing the plaintext in `plainPasswords`.
  /// Used to preserve hashes copied from the web database.
  static const Map<String, String> preHashedPasswords = {
    'rjayon43@gmail.com':
        r'$2a$12$9gsZSS/qoXdmPuX7WTKbn.Ct0ECDI/M9ZRM4Gjw..wrIgzN3eeY4.',
  };

  static const List<Map<String, dynamic>> users = [
    {
      'full_name': 'Administrator',
      'username': 'admin',
      'email': 'admin@alight.local',
      'bio':
          'Beginner motion designer on a mission to learn Alight Motion. Small steps, big edits.',
      'avatar_path': 'uploads/avatars/user_1_1791123244_c13815b022cb.webp',
      'banner_path': null,
      'gender': null,
      'gender_custom': null,
      'birthdate': '2007-10-01',
      'role': 'admin',
    },
    {
      'full_name': 'Minute Motion',
      'username': 'minutemotion',
      'email': 'minutemotion@gmail.com',
      'bio': 'Here to help you make the best videos possible',
      'avatar_path': 'uploads/avatars/user_2_1791082402_a860225c8716.webp',
      'banner_path': 'uploads/banners/banner_2_1791082465_2b646b6da0f6.webp',
      'gender': 'Male',
      'gender_custom': null,
      'birthdate': '1976-11-16',
      'role': 'user',
    },
    {
      'full_name': 'RJayOn',
      'username': 'rjay0n43',
      'email': 'rjayon43@gmail.com',
      'bio':
          '🌱 Beginner motion designer on a mission to learn Alight Motion. Small steps, big edits.',
      'avatar_path': 'uploads/avatars/user_3_1791157819_32bbf41c23c5.webp',
      'banner_path': 'uploads/banners/banner_3_1791105089_b8b4198d3455.webp',
      'gender': 'Male',
      'gender_custom': null,
      'birthdate': '2007-10-01',
      'role': 'user',
    },
    {
      'full_name': 'Wizzy',
      'username': 'wizzytutorials',
      'email': 'wizzytuts@gmail.com',
      'bio': 'Wanna be a Pro Alightmotion editor like me me ?',
      'avatar_path': 'uploads/avatars/user_4_1791120118_943d5c38a68b.webp',
      'banner_path': null,
      'gender': 'Male',
      'gender_custom': null,
      'birthdate': '1978-10-01',
      'role': 'user',
    },
    {
      'full_name': 'Loki Poki',
      'username': 'loki_poki',
      'email': 'lokipoki@gmail.com',
      'bio':
          'Hi, I\'m Loki!\nThis is a place for you to be you and me to be me. I hope you enjoy my videos! I\'ve been in this community for over four years and still love the thrill of being a content creator.\n\nMy TikTok account: @loki_poki.official',
      'avatar_path': 'uploads/avatars/user_5_1791120512_7d9a2f7c800a.webp',
      'banner_path': null,
      'gender': 'Male',
      'gender_custom': null,
      'birthdate': '2001-12-02',
      'role': 'user',
    },
  ];

  static const List<Map<String, dynamic>> tutorials = [
    {
      'user_id': 2,
      'title': 'Motion Blur Tutorial',
      'description':
          'This quick Minute Motion tutorial shows how to find, apply, and adjust the Motion Blur effect in Alight Motion for smoother animations.',
      'category': 'Beginner',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791083949_4d7f529f042c.webp',
      'guide_video_file':
          'uploads/videos/guide_1791083949_18c68091682d.mp4',
      'result_video_file':
          'uploads/videos/result_1791083949_e6e28c5a487a.mp4',
      'views': 3,
      'created_at': '2026-10-04 03:19:09',
      'steps': [
        {
          'title': 'Add the Motion Blur Effect',
          'desc':
              'Select the specific layer you want to animate. Tap on "Effects" in the bottom menu, select "Add Effect," navigate to the "Blur" category, and choose "Motion Blur" using the Standard Settings.',
        },
      ],
    },
    {
      'user_id': 2,
      'title': 'Spring Animation Like h0',
      'description':
          'A quick guide on creating a 3D bouncing spring animation using shape masking, the Flip Layer effect, and keyframing in Alight Motion.',
      'category': 'Intermediate',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791085590_b00369b68f61.webp',
      'guide_video_file':
          'uploads/videos/guide_1791085590_6d4aea7b8507.mp4',
      'result_video_file': null,
      'views': 1,
      'created_at': '2026-10-04 03:46:06',
      'steps': [
        {
          'title': 'Create the Base Ring',
          'desc':
              'Add a circle shape, remove the fill, and add a stroke. Apply the "Drawing Progress" effect and add keyframes from 0 to 100 on the "End" property so the line draws itself. Adjust the animation graph for smooth movement.',
        },
        {
          'title': 'Mask and Add 3D Perspective',
          'desc':
              'Add a square shape that is larger than the circle and place it above the circle layer. Select both layers and group them to mask the layer. On this newly grouped layer, add the "Flip Layer" effect, setting the Angle to 75 and the Axis to 90 to create a tilted look.',
        },
        {
          'title': 'Duplicate and Scale',
          'desc':
              'Extend the layer duration by dragging it, then duplicate the masked group layer. Scale the new duplicated layer down just a little bit. Repeat this process two or more times to create the different rings of the spring.',
        },
        {
          'title': 'Animate the Spring Motion',
          'desc':
              'Use the Move & Transform tool to add keyframes to each duplicated circle, moving them downward below the previous circle. Copy and paste the animation graph for consistency, then add later keyframes to move them back up, making the smallest circle sit at the top and the biggest at the bottom to complete the spring illusion.',
        },
      ],
    },
    {
      'user_id': 3,
      'title': 'Graphs You Didn\'t Know',
      'description':
          'A visual guide to understanding how different animation graphs in Alight Motion affect the movement and style of your layers and effects.',
      'category': 'Tips & Tricks',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791105651_3fc06a6de38a.webp',
      'guide_video_file':
          'uploads/videos/guide_1791105651_a6fa2b509e03.mp4',
      'result_video_file': null,
      'views': 2,
      'created_at': '2026-10-04 09:20:51',
      'steps': [
        {
          'title': 'Elastic Graphs',
          'desc':
              'Use this graph to make bouncy text animations, dynamic motion graphics, and even shake effects without needing to use the oscillate effect.',
        },
        {
          'title': 'Bounce Graphs',
          'desc':
              'This graph is designed specifically for creating natural, repeating bouncing motions, like a bouncing ball animation hitting a floor.',
        },
        {
          'title': 'Cyclic Graphs',
          'desc':
              'Apply this repeating graph to create looped or continuous animations that need to cycle through the same motion indefinitely.',
        },
        {
          'title': 'Steps Graphs',
          'desc':
              'Use this graph for animations that need to have hard stops in between movements, such as a ticking clock hand or a stop-motion style effect.',
        },
      ],
    },
    {
      'user_id': 2,
      'title': 'How To Use Pixelate',
      'description':
          'A brief guide explaining the settings of the Pixellate effect in Alight Motion, demonstrating how to adjust size, stretch, and screen space to create a vintage or retro blocky appearance.',
      'category': 'Beginner',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791106938_a95b6b7b5c1b.webp',
      'guide_video_file':
          'uploads/videos/guide_1791106938_5e5907a9b260.mp4',
      'result_video_file': null,
      'views': 1,
      'created_at': '2026-10-04 09:42:18',
      'steps': [
        {
          'title': 'Adjust the Pixel Size',
          'desc':
              'Use the "Size" setting to change the dimensions of the pixel squares. A smaller number keeps the clip clearer, while a larger number makes the image more blocky and unclear.',
        },
        {
          'title': 'Stretch the Pixels',
          'desc':
              'Use the "Stretch" setting to elongate the squares along the X-axis or Y-axis. Increasing the number will stretch the pixels further in your chosen direction.',
        },
        {
          'title': 'Fine-Tune Angles and Vignette',
          'desc':
              'Adjust the "Angle" to rotate the pixel pattern. This also applies a vignette effect to the squares, which becomes much more noticeable when the pixel size is increased.',
        },
        {
          'title': 'Toggle Screen Space',
          'desc':
              'Turn on "Screen Space" to ensure the pixel squares scale up or down in a consistent, uniform manner when the layer is animated.',
        },
        {
          'title': 'Clean Up Edges for Shapes',
          'desc':
              'If you are applying the effect to a unique shape, use the Alpha, Threshold, and Saturation settings to make the squares on the edges clearer and less transparent.',
        },
      ],
    },
    {
      'user_id': 2,
      'title': 'How To Use Tiles',
      'description':
          'A very quick, visual demonstration of the Tiles effect in Alight Motion, showing how its various settings change the appearance of a layer and why it is essential for creating smooth transitions.',
      'category': 'Beginner',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791118763_0203900dc73e.webp',
      'guide_video_file':
          'uploads/videos/guide_1791118763_42ac63921584.mp4',
      'result_video_file': null,
      'views': 3,
      'created_at': '2026-10-04 12:59:23',
      'steps': [
        {
          'title': 'Cropping and Duplicating',
          'desc':
              'Add the Tiles effect to your layer. The "Crop" setting scales the original image down, automatically filling the empty space around it with duplicated tiles of your clip.',
        },
        {
          'title': 'Offset and Mirroring',
          'desc':
              'Use the "Offset" setting to slide the duplicated tiles horizontally, or toggle on "Offset Vertically" to slide them up and down. Turn on the "Mirror" toggle to flip every other tile, which helps hide the harsh edges between the duplicated images.',
        },
        {
          'title': 'Changing the Angle',
          'desc':
              'Adjust the "Angle" setting to rotate the entire grid of tiled images.',
        },
        {
          'title': 'Using Tiles for Transitions',
          'desc':
              'The most common use for the Tiles effect is during transitions. When you add movement (like a slide or zoom) to a clip, the Tiles effect ensures there are no empty black spaces visible on the screen as the layer moves.',
        },
      ],
    },
    {
      'user_id': 2,
      'title': 'How Do I Use Random Displacement?',
      'description':
          'A visual guide explaining the settings of the Random Displacement effect in Alight Motion and how to combine it with other tools to create a custom shake transition',
      'category': 'Intermediate',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791119119_39fa7d163b42.webp',
      'guide_video_file':
          'uploads/videos/guide_1791119119_5340a47d5f90.mp4',
      'result_video_file': null,
      'views': 1,
      'created_at': '2026-10-04 13:05:19',
      'steps': [
        {
          'title': 'Understand the Core Settings',
          'desc':
              'Add the Random Displacement effect to move your layer smoothly but randomly. Adjust the "Evolution" setting to control the movement over time, and use "Magnitude" to determine how strong you want the overall movement to be.',
        },
        {
          'title': 'Adjust Variation and Chaos',
          'desc':
              'Change the "Seed" setting to alter the specific variation or pattern of the animation, which can also be keyframed for an extra shake effect. Adjust the "Scatter" setting to control how chaotic you want the animation to appear.',
        },
        {
          'title': 'Build the Base for a Transition',
          'desc':
              'To create a quick shake transition, start by animating your image\'s scale so it goes from a larger size down to its regular size using a custom animation graph. Next, add the "Tiles" effect and turn on the "Mirror" toggle to fill any empty edges that appear during the movement.',
        },
        {
          'title': 'Finalize the Shake',
          'desc':
              'Apply the "Random Displacement" effect to the transitioning layer to introduce the erratic shake movement. Finally, add the "Motion Blur" effect to ensure the quick, random movements blend together and look natural.',
        },
      ],
    },
    {
      'user_id': 2,
      'title': 'Use Contour Lines & Contour Gradients',
      'description':
          'A concise guide explaining the Contour Lines and Contour Gradients effects in Alight Motion, highlighting how they differ from standard borders and how to animate them.',
      'category': 'Intermediate',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791119273_685463d02f66.webp',
      'guide_video_file':
          'uploads/videos/guide_1791119273_4066bba1e8d6.mp4',
      'result_video_file': null,
      'views': 2,
      'created_at': '2026-10-04 13:07:53',
      'steps': [
        {
          'title': 'Adjust Thickness and Distance',
          'desc':
              'Add the Contour Lines effect. Use the "Width" setting to make the lines thicker or thinner, and use the "Outset" setting to control how close or far away the lines are from your shape.',
        },
        {
          'title': 'Control the Number of Lines',
          'desc':
              'Unlike a regular stroke or border, this effect allows multiple lines. Adjust the "Count" setting to generate anywhere from 1 to 10 lines around your layer.',
        },
        {
          'title': 'Animate Line Movement',
          'desc':
              'Create motion by animating the "Phase" setting. Add a keyframe at the beginning and another at the end with a different phase value to make the lines continuously move inward or outward.',
        },
        {
          'title': 'Switch to Contour Gradients',
          'desc':
              'For a smooth color blend, use the Contour Gradient effect instead. This gives you two color options, but note that it restricts you to a single, stationary line without the ability to adjust the Count or move it with Phase.',
        },
      ],
    },
    {
      'user_id': 2,
      'title': 'How To Make Burst Animation',
      'description':
          'A tutorial on creating a dynamic burst animation in Alight Motion by combining vector lines, the Radial Repeat effect, and the Drawing Progress effect to simulate a bursting motion.',
      'category': 'Advanced',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791119403_b781941e7115.webp',
      'guide_video_file':
          'uploads/videos/guide_1791119403_a455c1a7158e.mp4',
      'result_video_file': null,
      'views': 1,
      'created_at': '2026-10-04 13:10:03',
      'steps': [
        {
          'title': 'Create the Base Lines',
          'desc':
              'Draw a line (you can curve it slightly), remove the fill, and add a stroke. Apply the "Radial Repeat" effect to easily duplicate the lines in a circular pattern, and set the radius to zero.',
        },
        {
          'title': 'Animate the End Point',
          'desc':
              'Add the "Drawing Progress" effect. Tap on the "End" property, add a keyframe at 0 and a second keyframe at 100. Adjust the animation graph to smooth out the movement.',
        },
        {
          'title': 'Animate the Start Point',
          'desc':
              'Next, tap on the "Start" property and add keyframes at 0 and 100. Position these keyframes slightly behind the "End" keyframes on your timeline, and apply a custom graph so the line disappears as it bursts outward.',
        },
        {
          'title': 'Duplicate and Offset',
          'desc':
              'To make the burst look more dynamic, duplicate your completed animation layer, change its color, and rotate it just a little bit. Offset the new layers by moving them slightly behind the original on the timeline.',
        },
      ],
    },
    {
      'user_id': 2,
      'title': 'How to Use Hot Colour',
      'description':
          'A quick tutorial explaining the "Hot Color" effect in Alight Motion, which remaps grayscale or luminance values into an intense, glowing colored image, often used for color grading or glowing outlines.',
      'category': 'Intermediate',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791119741_21c6f10b99e7.webp',
      'guide_video_file':
          'uploads/videos/guide_1791119741_d6ffc15b7b7e.mp4',
      'result_video_file': null,
      'views': 1,
      'created_at': '2026-10-04 13:15:41',
      'steps': [
        {
          'title': 'Understand the Color Wheel',
          'desc':
              'Add the Hot Color effect to your image or video. Use the "Color" setting\'s color wheel; moving the selector closer to the center removes color, while moving it further from the center increases the color intensity.',
        },
        {
          'title': 'Understand the Tint Wheel',
          'desc':
              'The "Tint" setting works exactly the same way. Moving it to the center means no color, and moving it outward adds intense tint. You can choose to use both, Color only, or Tint only.',
        },
        {
          'title': 'Adjust the Black and White Values',
          'desc':
              'On the right side of both the Color and Tint settings, there is a slider. Pushing this slider up brings out more white, while pushing it down brings out more black in your remapped image.',
        },
        {
          'title': 'Experiment for Different Styles',
          'desc':
              'Hot Color can be highly dependent on the original video or image. Experiment with moving one selector closer to the center and the other further away to create unique color correction, color grading, or intense glowing outline effects.',
        },
      ],
    },
    {
      'user_id': 4,
      'title': '3 Tricks to Edit Faster and Better',
      'description':
          'A guide by Wizzy Tutorials covering three techniques to significantly speed up your editing workflow in Alight Motion: saving effect presets, creating reusable Elements, and using LUTs for color correction.',
      'category': 'Tips & Tricks',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791120253_ec90a493ed4e.webp',
      'guide_video_url': 'https://www.youtube.com/watch?v=vFgs5izmoOc',
      'guide_video_file': null,
      'result_video_file': null,
      'views': 1,
      'created_at': '2026-10-04 13:24:13',
      'steps': [
        {
          'title': 'Save and Use Effect Presets',
          'desc':
              'To save time on transitions, shakes, or text animations, save your effect settings as a preset. Click the preset icon on your clip\'s effects panel and press the save button. To apply it later, simply tap a new clip, navigate to presets, and select your saved effect.',
        },
        {
          'title': 'Create and Import Elements',
          'desc':
              'Elements allow you to save multiple layers (like 3D text setups or shape transitions) at once. Group your desired layers together, tap the save button, and choose "Save as Element". You can import these elements into any project instantly, and convert them back into a group if you need to edit them.',
        },
        {
          'title': 'Use LUTs for Color Correction',
          'desc':
              'You can save Color Correction (CC) settings onto a PNG using Look-Up Tables (LUTs). By using the "Lutstealer" effect on a shape or PNG in RAW mode, you can apply your custom CC on top and export it as a PNG, allowing you to use advanced color grading from other software directly inside Alight Motion.',
        },
      ],
    },
    {
      'user_id': 5,
      'title': '5 Tips I Wish I Knew Earlier as an Animator',
      'description':
          'Detailing five intermediate-to-advanced tips for Alight Motion, focusing heavily on character animation, rigging, and visual effects like sticker borders and realistic hair movement.',
      'category': 'Tips & Tricks',
      'thumbnail_path':
          'uploads/thumbnails/tut_1791120746_9153c4d0e383.webp',
      'guide_video_url': 'https://youtube.com/watch?v=I7_npO4tEa4',
      'guide_video_file': null,
      'result_video_file': null,
      'views': 2,
      'created_at': '2026-10-04 13:32:26',
      'steps': [
        {
          'title': 'Create a Sticker Outline Effect',
          'desc':
              'Select your character layer and add a border, adjusting the thickness to your liking. Add a second, thinner border in a darker color (like black) to make it look like a cutout sticker. Finally, add a drop shadow to soften the edges so it blends better with the background.',
        },
        {
          'title': 'Extend Multiple Layers Easily',
          'desc':
              'To avoid awkward disappearances when your background isn\'t as long as your character, select both layers as if you were going to group them, but don\'t actually group them. Drag out the timeline to your desired length and fully extend them at the same time, preventing any white spots from being left behind.',
        },
        {
          'title': 'Build a Puppet Rig with Parenting',
          'desc':
              'Instead of grouping, use the "Parenting" feature to connect layers (e.g., eyes to a head, head to a torso) by clicking the two squares at the top of the layer name and selecting the parent layer. This creates a puppet rig where moving the torso automatically moves the head and arms, but still allows each part to be animated individually.',
        },
        {
          'title': 'Animate Swaying Hair',
          'desc':
              'Make sure your pivot point is at the top of the hair where it connects to the head, then add the "Bend" effect. Add a keyframe at the start (bending to one side) and a keyframe at the end (bending to the other), then apply a looping graph for a fluent sway. For a different style, use the "Wave Warp" effect (Angle at 90) and adjust the dampening and magnitude.',
        },
        {
          'title': 'Animate Fluent Face Movement',
          'desc':
              'Add a circle the size of your character\'s face, change its fill to a circular gradient (white inside, black outside), and place it over the face. Add a "Displacement Map" effect, which will use that gradient circle to smoothly move and warp the character\'s facial features when you adjust the X and Y settings.',
        },
      ],
    },
  ];

  /// (tutorial_id, user_id, quality, clarity)
  static const List<List<int>> ratings = [
    [11, 3, 5, 5],
    [1, 5, 5, 5],
    [1, 3, 5, 5],
    [5, 3, 5, 5],
    [10, 3, 5, 5],
    [9, 3, 5, 5],
    [8, 3, 5, 5],
    [7, 3, 5, 5],
    [6, 3, 5, 5],
    [4, 3, 5, 5],
    [2, 3, 5, 5],
  ];

  /// (tutorial_id, user_id)
  static const List<List<int>> views = [
    [1, 3],
    [2, 3],
    [3, 2],
    [11, 3],
    [1, 5],
    [5, 5],
    [5, 3],
    [10, 3],
    [9, 3],
    [8, 3],
    [7, 3],
    [6, 3],
    [4, 3],
    [3, 5],
    [1, 1],
    [5, 1],
    [11, 1],
    [7, 1],
  ];

  /// (lover_id, loved_id)
  static const List<List<int>> loves = [
    [3, 2],
    [1, 2],
  ];
}