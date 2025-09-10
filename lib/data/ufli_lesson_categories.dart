class UFLILessonCategories {
  // Main category structure
  static const Map<String, dynamic> lessonHierarchy = {
    'Basic Lists': {
      'items': [
        {'id': 'kindergarten', 'label': '📚 Kindergarten Sight Words'},
        {'id': 'first', 'label': '📚 First Grade Trick Words'},
        {'id': 'second', 'label': '📚 Second Grade Trick Words'},
      ],
    },
    'UFLI Categories': {
      'items': [
        {'id': 'ufli_short_vowels', 'label': '🔤 Short Vowels'},
        {'id': 'ufli_cvce', 'label': '✨ CVCe Words (Magic E)'},
        {'id': 'ufli_blends', 'label': '🔗 Consonant Blends'},
        {'id': 'ufli_digraphs', 'label': '📝 Digraphs'},
        {'id': 'ufli_advanced', 'label': '🎓 Advanced Phonics'},
      ],
    },
    'UFLI Kindergarten': {
      'subCategories': {
        'Letter Introduction': {
          'description': 'Single letter sounds and basic CVC',
          'lessons': [
            {'id': 'lesson_13', 'label': 'Lesson 13: d /d/', 'words': _lesson13Words},
            {'id': 'lesson_14', 'label': 'Lesson 14: c /k/', 'words': _lesson14Words},
            {'id': 'lesson_15', 'label': 'Lesson 15: u /ŭ/', 'words': _lesson15Words},
            {'id': 'lesson_16', 'label': 'Lesson 16: g /g/', 'words': _lesson16Words},
            {'id': 'lesson_17', 'label': 'Lesson 17: b /b/', 'words': _lesson17Words},
            {'id': 'lesson_18', 'label': 'Lesson 18: e /ĕ/', 'words': _lesson18Words},
          ],
        },
        'Short Vowels': {
          'description': 'Short vowel review and practice',
          'lessons': [
            {'id': 'lesson_35a', 'label': 'Lesson 35a: Short a Review', 'words': _lesson35aWords},
            {'id': 'lesson_35c', 'label': 'Lesson 35c: Short a Advanced', 'words': _lesson35cWords},
            {'id': 'lesson_36a', 'label': 'Lesson 36a: Short i Review', 'words': _lesson36aWords},
            {'id': 'lesson_36b', 'label': 'Lesson 36b: Short i Advanced', 'words': _lesson36bWords},
            {'id': 'lesson_37a', 'label': 'Lesson 37a: Short o Review', 'words': _lesson37aWords},
            {'id': 'lesson_39a', 'label': 'Lesson 39a: Short u Review', 'words': _lesson39aWords},
            {'id': 'lesson_40a', 'label': 'Lesson 40a: Short e Review', 'words': _lesson40aWords},
          ],
        },
        'Digraphs & Blends': {
          'description': 'Two-letter combinations',
          'lessons': [
            {'id': 'lesson_45', 'label': 'Lesson 45: sh /sh/', 'words': _lesson45Words},
            {'id': 'lesson_46', 'label': 'Lesson 46: th /th/', 'words': _lesson46Words},
            {'id': 'lesson_48', 'label': 'Lesson 48: ch /ch/', 'words': _lesson48Words},
            {'id': 'lesson_49', 'label': 'Lesson 49: Digraphs Review', 'words': _lesson49Words},
            {'id': 'lesson_51', 'label': 'Lesson 51: ng /ŋ/', 'words': _lesson51Words},
          ],
        },
        'Advanced Skills': {
          'description': 'Compound words and syllables',
          'lessons': [
            {'id': 'lesson_65', 'label': 'Lesson 65: -ing', 'words': _lesson65Words},
            {'id': 'lesson_67a', 'label': 'Lesson 67a: Compound Words', 'words': _lesson67aWords},
            {'id': 'lesson_68', 'label': 'Lesson 68: Open/Closed Syllables', 'words': _lesson68Words},
          ],
        },
      },
    },
    'UFLI First Grade': {
      'subCategories': {
        'Review & Foundation': {
          'description': 'Review of kindergarten skills',
          'lessons': [
            {'id': 'lesson_41b_1st', 'label': 'Lesson 41b: Short Vowel Review', 'words': _lesson41bWords},
            {'id': 'lesson_43_1st', 'label': 'Lesson 43: -all, -oll, -ull', 'words': _lesson43Words},
            {'id': 'lesson_53_1st', 'label': 'Lesson 53: Digraphs Review', 'words': _lesson53Words},
          ],
        },
        'R-Controlled Vowels': {
          'description': 'Vowels with R sounds',
          'lessons': [
            {'id': 'lesson_77', 'label': 'Lesson 77: ar /ar/', 'words': _lesson77Words},
            {'id': 'lesson_78', 'label': 'Lesson 78: or /or/', 'words': _lesson78Words},
            {'id': 'lesson_80', 'label': 'Lesson 80: er /er/', 'words': _lesson80Words},
            {'id': 'lesson_81', 'label': 'Lesson 81: ir, ur /er/', 'words': _lesson81Words},
            {'id': 'lesson_83', 'label': 'Lesson 83: R-Controlled Review', 'words': _lesson83Words},
          ],
        },
        'Vowel Teams': {
          'description': 'Two vowels making one sound',
          'lessons': [
            {'id': 'lesson_84_ai', 'label': 'Lesson 84: ai /ā/', 'words': _lesson84AiWords},
            {'id': 'lesson_84_ay', 'label': 'Lesson 84: ay /ā/', 'words': _lesson84AyWords},
            {'id': 'lesson_85_ea', 'label': 'Lesson 85: ea /ē/', 'words': _lesson85EaWords},
            {'id': 'lesson_85_ee', 'label': 'Lesson 85: ee /ē/', 'words': _lesson85EeWords},
            {'id': 'lesson_86_oa', 'label': 'Lesson 86: oa /ō/', 'words': _lesson86OaWords},
            {'id': 'lesson_90', 'label': 'Lesson 90: oo /ū/', 'words': _lesson90Words},
          ],
        },
        'Diphthongs': {
          'description': 'Gliding vowel sounds',
          'lessons': [
            {'id': 'lesson_95', 'label': 'Lesson 95: oi, oy /oi/', 'words': _lesson95Words},
            {'id': 'lesson_96_ou', 'label': 'Lesson 96: ou /ow/', 'words': _lesson96OuWords},
            {'id': 'lesson_96_ow', 'label': 'Lesson 96: ow /ow/', 'words': _lesson96OwWords},
          ],
        },
        'Suffixes & Prefixes': {
          'description': 'Word endings and beginnings',
          'lessons': [
            {'id': 'lesson_100', 'label': 'Lesson 100: -er/-est', 'words': _lesson100Words},
            {'id': 'lesson_101', 'label': 'Lesson 101: -ly', 'words': _lesson101Words},
            {'id': 'lesson_103', 'label': 'Lesson 103: un-', 'words': _lesson103Words},
            {'id': 'lesson_107_ed', 'label': 'Lesson 107: Double Consonant -ed', 'words': _lesson107EdWords},
            {'id': 'lesson_109', 'label': 'Lesson 109: Drop e', 'words': _lesson109Words},
          ],
        },
      },
    },
    'UFLI Second Grade': {
      'subCategories': {
        'Review': {
          'description': 'Review of first grade skills',
          'lessons': [
            {'id': 'lesson_38a_2nd', 'label': 'Lesson 38a: Short a, i, o Review', 'words': _lesson38aWords},
            {'id': 'lesson_88', 'label': 'Lesson 88: Vowel Teams Review', 'words': _lesson88Words},
            {'id': 'lesson_97', 'label': 'Lesson 97: Diphthongs Review', 'words': _lesson97Words},
          ],
        },
        'Advanced R-Controlled': {
          'description': 'Complex R-controlled patterns',
          'lessons': [
            {'id': 'lesson_111', 'label': 'Lesson 111: er, ar, or', 'words': _lesson111Words},
            {'id': 'lesson_112', 'label': 'Lesson 112: air, are, ear', 'words': _lesson112Words},
            {'id': 'lesson_113', 'label': 'Lesson 113: ear /ear/', 'words': _lesson113Words},
          ],
        },
        'Advanced Suffixes': {
          'description': 'Complex word endings',
          'lessons': [
            {'id': 'lesson_119_tion', 'label': 'Lesson 119: -tion', 'words': _lesson119TionWords},
            {'id': 'lesson_119_sion', 'label': 'Lesson 119: -sion', 'words': _lesson119SionWords},
            {'id': 'lesson_120', 'label': 'Lesson 120: -ture', 'words': _lesson120Words},
            {'id': 'lesson_121_er', 'label': 'Lesson 121: -er (person)', 'words': _lesson121ErWords},
            {'id': 'lesson_121_ist', 'label': 'Lesson 121: -ist', 'words': _lesson121IstWords},
            {'id': 'lesson_124', 'label': 'Lesson 124: -ness', 'words': _lesson124Words},
            {'id': 'lesson_125', 'label': 'Lesson 125: -ment', 'words': _lesson125Words},
            {'id': 'lesson_126', 'label': 'Lesson 126: -able/-ible', 'words': _lesson126Words},
          ],
        },
        'Prefixes': {
          'description': 'Word beginnings',
          'lessons': [
            {'id': 'lesson_104', 'label': 'Lesson 104: pre-, re-', 'words': _lesson104Words},
            {'id': 'lesson_105', 'label': 'Lesson 105: dis-', 'words': _lesson105Words},
            {'id': 'lesson_127', 'label': 'Lesson 127: uni-, bi-, tri-', 'words': _lesson127Words},
          ],
        },
      },
    },
  };

  // Sample word lists for key lessons (we'll expand this)
  static const List<String> _lesson13Words = ['ad', 'dad', 'add', 'mad', 'sad', 'bad', 'had', 'lad', 'pad'];
  static const List<String> _lesson14Words = ['cab', 'can', 'cap', 'cat', 'cot', 'cod', 'cob'];
  static const List<String> _lesson15Words = ['up', 'us', 'bus', 'cup', 'cut', 'dug', 'fun', 'gun', 'hug', 'jug', 'mud', 'nut'];
  static const List<String> _lesson16Words = ['bag', 'big', 'bug', 'dig', 'dog', 'egg', 'fig', 'fog', 'gag', 'gap', 'gas', 'got', 'hog', 'jog', 'lag', 'leg', 'log', 'pig'];
  static const List<String> _lesson17Words = ['bad', 'bag', 'ban', 'bat', 'bed', 'beg', 'bet', 'bib', 'bid', 'big', 'bin', 'bit', 'bob', 'bog', 'bop', 'bot', 'bud', 'bug', 'bum', 'bun', 'bus', 'but', 'cab', 'cub', 'dab'];
  static const List<String> _lesson18Words = ['bed', 'beg', 'bet', 'den', 'egg', 'fed', 'get', 'hen', 'jet', 'leg', 'let', 'men', 'met', 'net'];
  
  // Kindergarten lessons
  static const List<String> _lesson35aWords = ['am', 'an', 'at', 'bad', 'bag', 'cab', 'can', 'cat', 'dad', 'dam', 'fan', 'fat', 'gap', 'gas', 'had', 'ham', 'hat', 'jam', 'lab', 'lap', 'mad', 'man', 'map', 'mat', 'nap', 'pan', 'pat', 'rag', 'ram', 'ran', 'rat', 'sad', 'sag', 'sat', 'tab', 'tag'];
  static const List<String> _lesson35cWords = ['ask', 'band', 'blab', 'brag', 'camp', 'cast', 'clam', 'clap', 'crab', 'cram', 'damp', 'drag', 'fast', 'flag', 'flap', 'flat', 'glad', 'grab', 'last', 'mask', 'mast', 'pact', 'pant', 'past', 'raft', 'rasp', 'sand', 'scab', 'scam', 'scan', 'slab', 'slam', 'slap', 'snag', 'task', 'vast'];
  static const List<String> _lesson36aWords = ['big', 'bin', 'bit', 'did', 'dig', 'dim', 'dip', 'fig', 'fin', 'fit', 'gig', 'hid', 'him', 'hip', 'hit', 'jig', 'kid', 'kit', 'lid', 'lip', 'lit', 'mid', 'mix', 'nit', 'pig', 'pin', 'pit', 'rib', 'rid', 'rim', 'rip', 'sip', 'sit', 'tip', 'wig', 'win'];
  static const List<String> _lesson36bWords = ['brim', 'chip', 'chin', 'clip', 'crib', 'drip', 'fist', 'flip', 'gift', 'grim', 'grin', 'grip', 'hint', 'king', 'list', 'milk', 'mint', 'mist', 'pink', 'print', 'quit', 'risk', 'shift', 'ship', 'silk', 'sink', 'skip', 'slim', 'slip', 'spin', 'spit', 'swim', 'thin', 'trick', 'trim', 'twin'];
  static const List<String> _lesson37aWords = ['bob', 'bog', 'box', 'cob', 'cod', 'cop', 'cot', 'dog', 'dot', 'fog', 'got', 'hog', 'hop', 'hot', 'job', 'jog', 'jot', 'log', 'lot', 'mob', 'mop', 'nod', 'not', 'pod', 'pop', 'pot', 'rob', 'rod', 'rot', 'sob', 'sod', 'top', 'tot'];
  static const List<String> _lesson39aWords = ['bud', 'bug', 'bum', 'bun', 'bus', 'but', 'cub', 'cup', 'cut', 'dug', 'fun', 'gum', 'gun', 'gut', 'hub', 'hug', 'hum', 'hut', 'jug', 'jut', 'mud', 'mug', 'nut', 'pub', 'pup', 'rub', 'rug', 'run', 'rut', 'sub', 'sum', 'sun', 'tub', 'tug'];
  static const List<String> _lesson40aWords = ['bed', 'beg', 'bet', 'den', 'egg', 'fed', 'get', 'hen', 'hem', 'jet', 'leg', 'let', 'men', 'met', 'net', 'peg', 'pen', 'pet', 'red', 'set', 'ten', 'vet', 'web', 'wet', 'yes'];
  
  // Digraphs
  static const List<String> _lesson45Words = ['ash', 'bash', 'cash', 'dash', 'dish', 'fish', 'gash', 'gosh', 'gush', 'hash', 'hush', 'lash', 'mash', 'mesh', 'mush', 'push', 'rash', 'rush', 'sash', 'shed', 'shell', 'shift', 'shin', 'ship', 'shop', 'shot', 'shut', 'trash', 'wash', 'wish'];
  static const List<String> _lesson46Words = ['that', 'them', 'then', 'they', 'this', 'thus'];
  static const List<String> _lesson48Words = ['bench', 'bunch', 'catch', 'chat', 'chess', 'chest', 'chick', 'chin', 'chip', 'chop', 'chuck', 'chunk', 'clutch', 'hatch', 'hunch', 'inch', 'lunch', 'match', 'much', 'patch', 'pinch', 'punch', 'ranch', 'rich', 'such', 'watch', 'which'];
  static const List<String> _lesson49Words = ['bash', 'bench', 'branch', 'brush', 'catch', 'chat', 'chest', 'chin', 'dish', 'fish', 'flash', 'hatch', 'lunch', 'math', 'match', 'mesh', 'moth', 'much', 'path', 'punch', 'ranch', 'rich', 'rush', 'ship', 'shop', 'shut', 'slash', 'splash', 'such', 'that', 'them', 'then', 'thick', 'thin', 'trash', 'which'];
  static const List<String> _lesson51Words = ['bang', 'bring', 'cling', 'fang', 'gang', 'hang', 'king', 'long', 'lung', 'rang', 'ring', 'sang', 'sing', 'song', 'sting', 'string', 'strong', 'sung', 'swing', 'thing', 'wing', 'wrong', 'young'];
  
  // Advanced kindergarten
  static const List<String> _lesson65Words = ['acting', 'asking', 'banking', 'batting', 'begging', 'betting', 'billing', 'biting', 'boxing', 'bringing', 'camping', 'catching', 'cutting', 'digging', 'dressing', 'drilling', 'dropping', 'fishing', 'getting', 'helping', 'hitting', 'jumping', 'kicking', 'landing', 'running', 'shopping', 'sitting', 'swimming'];
  static const List<String> _lesson67aWords = ['backpack', 'baseball', 'basketball', 'bathtub', 'bedrock', 'blackbird', 'blacktop', 'bulldog', 'buttercup', 'cannot', 'catfish', 'cupcake', 'desktop', 'dishpan', 'drumstick', 'eggshell', 'fingernail', 'football', 'grassland', 'hotdog', 'inside', 'laptop', 'lunchbox', 'nutshell', 'pancake', 'sandbox', 'sunfish', 'sunset', 'trashcan', 'windmill'];
  static const List<String> _lesson68Words = ['baby', 'basic', 'began', 'behind', 'below', 'beyond', 'broken', 'chosen', 'cricket', 'even', 'frozen', 'hotel', 'human', 'label', 'legal', 'lemon', 'moment', 'music', 'never', 'open', 'paper', 'pilot', 'planet', 'present', 'problem', 'project', 'rabbit', 'robot', 'seven', 'spider', 'student', 'taken', 'tiger', 'token', 'tulip', 'unit'];
  
  // First grade lessons
  static const List<String> _lesson41bWords = ['blast', 'brand', 'clamp', 'crisp', 'drift', 'frost', 'grand', 'grasp', 'grump', 'plant', 'plump', 'print', 'prompt', 'script', 'shrimp', 'slant', 'slept', 'spent', 'split', 'stamp', 'stand', 'stomp', 'strand', 'strip', 'stump', 'swift', 'trust', 'twist'];
  static const List<String> _lesson43Words = ['all', 'ball', 'call', 'fall', 'hall', 'mall', 'small', 'stall', 'tall', 'wall', 'doll', 'poll', 'roll', 'toll', 'bull', 'full', 'pull'];
  static const List<String> _lesson53Words = ['bench', 'branch', 'bunch', 'church', 'crunch', 'flash', 'graph', 'lunch', 'match', 'phone', 'photo', 'pinch', 'ranch', 'splash', 'stretch', 'switch', 'thing', 'think', 'thrash', 'three', 'throne', 'through', 'throw', 'thrust', 'whack', 'whale', 'wheat', 'wheel'];
  
  // R-controlled vowels
  static const List<String> _lesson77Words = ['arm', 'art', 'bar', 'bark', 'barn', 'car', 'card', 'cart', 'charm', 'chart', 'dark', 'dart', 'far', 'farm', 'guard', 'hard', 'harm', 'harp', 'jar', 'large', 'march', 'mark', 'park', 'part', 'scar', 'scarf', 'shark', 'sharp', 'smart', 'spark', 'star', 'start', 'tar', 'yard'];
  static const List<String> _lesson78Words = ['born', 'cord', 'cork', 'corn', 'for', 'fork', 'form', 'fort', 'horse', 'horn', 'morning', 'north', 'or', 'order', 'porch', 'port', 'short', 'snort', 'sort', 'sport', 'storm', 'story', 'thorn', 'torn', 'torch', 'worn'];
  static const List<String> _lesson80Words = ['after', 'better', 'center', 'clever', 'corner', 'danger', 'dinner', 'enter', 'ever', 'finger', 'flower', 'hammer', 'her', 'ladder', 'letter', 'monster', 'never', 'number', 'other', 'over', 'paper', 'pepper', 'perfect', 'river', 'rubber', 'silver', 'sister', 'spider', 'summer', 'thunder', 'under', 'water', 'winter'];
  static const List<String> _lesson81Words = ['bird', 'birth', 'burn', 'burst', 'church', 'circle', 'curl', 'curve', 'dirt', 'first', 'firm', 'fur', 'girl', 'hurt', 'nurse', 'purple', 'purse', 'return', 'shirt', 'sir', 'skirt', 'stir', 'surf', 'third', 'thirst', 'thirty', 'turn', 'turtle', 'twirl', 'urban', 'urge'];
  static const List<String> _lesson83Words = ['alarm', 'bitter', 'burger', 'carpet', 'corner', 'doctor', 'early', 'finger', 'forest', 'garden', 'hammer', 'ladder', 'market', 'modern', 'morning', 'partner', 'pepper', 'perfect', 'person', 'picture', 'porter', 'quarter', 'sister', 'spider', 'sport', 'started', 'summer', 'target', 'thirty', 'thunder', 'turkey', 'turtle', 'under', 'water', 'winter', 'worker'];
  
  // Vowel teams
  static const List<String> _lesson84AiWords = ['aid', 'aim', 'bait', 'braid', 'brain', 'chain', 'claim', 'drain', 'fail', 'faith', 'frail', 'grain', 'jail', 'laid', 'maid', 'mail', 'main', 'nail', 'paid', 'pail', 'pain', 'paint', 'plain', 'raid', 'rail', 'raise', 'sail', 'snail', 'strain', 'tail', 'trail', 'train', 'vain', 'wail', 'waist', 'wait'];
  static const List<String> _lesson84AyWords = ['bay', 'clay', 'day', 'gray', 'hay', 'jay', 'lay', 'may', 'pay', 'play', 'pray', 'ray', 'say', 'spray', 'stay', 'stray', 'sway', 'today', 'tray', 'way'];
  static const List<String> _lesson85EaWords = ['beach', 'bean', 'beat', 'cheap', 'clean', 'cream', 'deal', 'dream', 'each', 'eat', 'feast', 'heat', 'lead', 'lean', 'leap', 'meal', 'mean', 'meat', 'neat', 'peach', 'peak', 'peal', 'please', 'reach', 'read', 'real', 'scream', 'seal', 'seat', 'sneak', 'speak', 'squeak', 'steal', 'steam', 'stream', 'teach', 'team'];
  static const List<String> _lesson85EeWords = ['bee', 'beef', 'beep', 'beet', 'bleed', 'cheek', 'creek', 'creep', 'deed', 'deep', 'eel', 'feed', 'feel', 'feet', 'flee', 'free', 'geese', 'greed', 'green', 'greet', 'heel', 'jeep', 'keep', 'kneel', 'meet', 'need', 'peek', 'peel', 'queen', 'seed', 'seek', 'seem', 'seen', 'sheep', 'sheet', 'sleep', 'speed', 'steel', 'steep', 'street', 'sweep', 'sweet', 'teen', 'teeth', 'three', 'tree', 'weed', 'week', 'wheel'];
  static const List<String> _lesson86OaWords = ['boat', 'boast', 'cloak', 'coach', 'coal', 'coast', 'coat', 'croak', 'float', 'foam', 'goal', 'goat', 'groan', 'load', 'loaf', 'loan', 'moat', 'oak', 'oat', 'poach', 'road', 'roam', 'roast', 'soak', 'soap', 'throat', 'toad', 'toast'];
  static const List<String> _lesson90Words = ['bamboo', 'bloom', 'boo', 'boom', 'boot', 'broom', 'cartoon', 'choose', 'classroom', 'cool', 'coop', 'drool', 'food', 'fool', 'gloomy', 'goose', 'hoop', 'igloo', 'kangaroo', 'loop', 'moon', 'mood', 'moose', 'noodle', 'noon', 'ooze', 'pool', 'proof', 'raccoon', 'roof', 'room', 'rooster', 'root', 'school', 'scoop', 'shoot', 'smooth', 'snooze', 'soon', 'spoon', 'stool', 'swoop', 'tool', 'tooth', 'troop', 'zoo', 'zoom'];
  
  // Diphthongs
  static const List<String> _lesson95Words = ['boil', 'broil', 'choice', 'coil', 'coin', 'foil', 'hoist', 'join', 'joint', 'moist', 'noise', 'oil', 'oink', 'point', 'poison', 'soil', 'spoil', 'toil', 'voice', 'annoy', 'boy', 'cloy', 'coy', 'decoy', 'deploy', 'destroy', 'employ', 'enjoy', 'joy', 'loyal', 'ploy', 'royal', 'soy', 'toy', 'voyage'];
  static const List<String> _lesson96OuWords = ['about', 'around', 'bound', 'cloud', 'count', 'couch', 'flour', 'found', 'ground', 'house', 'loud', 'mount', 'mouse', 'mouth', 'ouch', 'ounce', 'out', 'pound', 'proud', 'round', 'scout', 'shout', 'sound', 'south', 'sprout', 'trout'];
  static const List<String> _lesson96OwWords = ['bow', 'brown', 'clown', 'cow', 'crowd', 'crown', 'drown', 'frown', 'gown', 'growl', 'how', 'howl', 'now', 'owl', 'plow', 'pow', 'prowl', 'scowl', 'town', 'towel', 'tower', 'vow', 'wow'];
  
  // Suffixes
  static const List<String> _lesson100Words = ['bigger', 'brighter', 'cleaner', 'closer', 'colder', 'darker', 'deeper', 'faster', 'fresher', 'harder', 'higher', 'kinder', 'lighter', 'longer', 'louder', 'newer', 'nicer', 'older', 'quicker', 'richer', 'safer', 'shorter', 'slower', 'smaller', 'smoother', 'softer', 'stronger', 'sweeter', 'taller', 'thicker', 'thinner', 'warmer', 'wider'];
  static const List<String> _lesson101Words = ['badly', 'bravely', 'briefly', 'brightly', 'calmly', 'clearly', 'closely', 'coldly', 'fairly', 'finally', 'friendly', 'gladly', 'greatly', 'hardly', 'kindly', 'lately', 'lightly', 'lonely', 'lovely', 'mostly', 'nearly', 'nicely', 'proudly', 'quickly', 'quietly', 'rarely', 'safely', 'slowly', 'smoothly', 'softly', 'strongly', 'suddenly', 'surely', 'sweetly', 'swiftly', 'warmly', 'weekly', 'widely', 'wildly'];
  static const List<String> _lesson103Words = ['unable', 'unafraid', 'unaware', 'unbroken', 'unclear', 'uncommon', 'uncover', 'undone', 'unfair', 'unfold', 'unhappy', 'unkind', 'unknown', 'unlocked', 'unlucky', 'unmade', 'unpack', 'unpaid', 'unreal', 'unsafe', 'unseen', 'unsure', 'untidy', 'untied', 'untrue', 'unused', 'unwrap', 'unzip'];
  static const List<String> _lesson107EdWords = ['batted', 'begged', 'chipped', 'chopped', 'clapped', 'dropped', 'drummed', 'flipped', 'grabbed', 'grinned', 'gripped', 'hopped', 'hugged', 'jogged', 'mapped', 'mopped', 'patted', 'planned', 'plotted', 'popped', 'rubbed', 'shipped', 'shopped', 'skipped', 'slapped', 'slipped', 'snapped', 'spotted', 'stepped', 'stopped', 'stripped', 'swapped', 'tapped', 'trapped', 'tripped', 'wrapped', 'zapped'];
  static const List<String> _lesson109Words = ['baked', 'blamed', 'braved', 'cared', 'chased', 'closed', 'danced', 'dated', 'faced', 'faded', 'filed', 'glided', 'graded', 'hiked', 'hoped', 'joked', 'lined', 'moved', 'named', 'paced', 'placed', 'prized', 'quoted', 'raced', 'raised', 'ruled', 'saved', 'scared', 'scored', 'shaded', 'shaped', 'shared', 'smiled', 'spaced', 'staged', 'stored', 'tamed', 'taped', 'tasted', 'traced', 'traded', 'voted', 'waved'];
  
  // Second grade lessons
  static const List<String> _lesson38aWords = ['act', 'add', 'and', 'ant', 'ask', 'back', 'bad', 'band', 'bat', 'big', 'bit', 'black', 'box', 'bring', 'can', 'cat', 'clap', 'clock', 'did', 'dig', 'dog', 'drop', 'fast', 'fat', 'fish', 'flag', 'flip', 'got', 'grab', 'grin', 'hand', 'hat', 'hit', 'hop', 'hot', 'job', 'kid', 'king', 'land', 'last', 'lip', 'lock', 'lot', 'mad', 'man', 'milk', 'mix', 'nod', 'not', 'pack', 'pig', 'plan', 'plot', 'pop', 'pot', 'print', 'quit', 'rock', 'sad', 'sand', 'sit', 'slap', 'slip', 'snack', 'snap', 'spot', 'stand', 'stick', 'stop', 'strip', 'swim', 'tank', 'tick', 'top', 'track', 'trap', 'trick', 'trip', 'trot', 'twist', 'will', 'win', 'wish'];
  static const List<String> _lesson88Words = ['afraid', 'always', 'away', 'beach', 'brain', 'bread', 'break', 'chain', 'cheap', 'clean', 'coach', 'coast', 'cream', 'display', 'dream', 'each', 'easy', 'explain', 'float', 'foam', 'free', 'goal', 'grain', 'great', 'green', 'groan', 'keep', 'leaf', 'lean', 'load', 'main', 'maybe', 'mean', 'need', 'oat', 'paint', 'peace', 'plain', 'play', 'please', 'pray', 'rain', 'reach', 'read', 'road', 'sail', 'say', 'seal', 'seat', 'sleep', 'snail', 'speak', 'spray', 'stay', 'steam', 'stream', 'sweet', 'teach', 'team', 'today', 'toast', 'trail', 'train', 'treat', 'tree', 'wait', 'way', 'weak', 'wheat'];
  static const List<String> _lesson97Words = ['about', 'allow', 'annoy', 'around', 'avoid', 'boil', 'bounce', 'bound', 'boy', 'brown', 'choice', 'clown', 'cloud', 'coin', 'couch', 'count', 'cow', 'crowd', 'crown', 'destroy', 'down', 'drown', 'employ', 'enjoy', 'flour', 'flower', 'found', 'frown', 'ground', 'growl', 'house', 'how', 'howl', 'join', 'joy', 'loud', 'loyal', 'moist', 'mount', 'mouse', 'mouth', 'noise', 'now', 'oil', 'out', 'owl', 'point', 'pound', 'powder', 'power', 'proud', 'round', 'royal', 'scout', 'shout', 'shower', 'soil', 'sound', 'south', 'spoil', 'sprout', 'thousand', 'towel', 'tower', 'town', 'toy', 'voice', 'vowel', 'wow'];
  
  // Advanced second grade
  static const List<String> _lesson111Words = ['actor', 'anger', 'archer', 'armor', 'barber', 'better', 'border', 'butter', 'cancer', 'center', 'chapter', 'charter', 'cider', 'clever', 'collar', 'corner', 'crater', 'danger', 'dealer', 'dinner', 'doctor', 'dollar', 'editor', 'enter', 'error', 'factor', 'farmer', 'father', 'feather', 'fiber', 'filter', 'finger', 'folder', 'freezer', 'gather', 'ginger', 'glitter', 'grammar', 'hammer', 'harbor', 'holder', 'hunger', 'hunter', 'ladder', 'leader', 'leather', 'letter', 'lumber', 'maker', 'manner', 'marker', 'master', 'matter', 'member', 'meter', 'mirror', 'modern', 'monster', 'mother', 'motor', 'number', 'offer', 'order', 'other', 'owner', 'paper', 'partner', 'pepper', 'player', 'poster', 'powder', 'power', 'printer', 'proper', 'quarter', 'ranger', 'rather', 'reader', 'render', 'rider', 'river', 'roller', 'rubber', 'ruler', 'runner', 'sailor', 'scatter', 'sender', 'senior', 'shelter', 'shiver', 'shoulder', 'shower', 'silver', 'singer', 'sister', 'slender', 'soccer', 'soldier', 'speaker', 'spider', 'splatter', 'starter', 'sticker', 'summer', 'super', 'supper', 'tender', 'terror', 'thunder', 'timber', 'trader', 'trailer', 'trigger', 'under', 'user', 'visitor', 'waiter', 'water', 'weather', 'whisper', 'winner', 'winter', 'wonder', 'worker', 'writer'];
  static const List<String> _lesson112Words = ['affair', 'aircraft', 'airline', 'airplane', 'airport', 'aware', 'beware', 'care', 'careful', 'chair', 'compare', 'dairy', 'declare', 'eclair', 'fair', 'fairy', 'flair', 'glare', 'hair', 'haircut', 'hairy', 'impair', 'lair', 'midair', 'pair', 'prairie', 'prepare', 'rare', 'repair', 'scare', 'share', 'software', 'square', 'stair', 'staircase', 'stare', 'unfair', 'upstairs', 'warfare', 'wear'];
  static const List<String> _lesson113Words = ['appear', 'bear', 'beard', 'clear', 'dear', 'disappear', 'ear', 'earl', 'early', 'earn', 'earth', 'fear', 'gear', 'hear', 'heard', 'heart', 'learn', 'near', 'nearly', 'pearl', 'rear', 'search', 'smear', 'spear', 'swear', 'tear', 'wear', 'weary', 'year', 'yearn'];
  static const List<String> _lesson119TionWords = ['action', 'addition', 'audition', 'caution', 'correction', 'digestion', 'equation', 'eruption', 'fiction', 'fraction', 'friction', 'imagination', 'introduction', 'intuition', 'location', 'lotion', 'motion', 'nation', 'operation', 'option', 'portion', 'position', 'question', 'reaction', 'rotation', 'section', 'solution', 'station', 'subtraction'];
  static const List<String> _lesson119SionWords = ['admission', 'collision', 'commission', 'compression', 'conclusion', 'confusion', 'decision', 'depression', 'dimension', 'discussion', 'division', 'erosion', 'expansion', 'explosion', 'expression', 'extension', 'illusion', 'impression', 'inclusion', 'mansion', 'mission', 'occasion', 'passion', 'pension', 'permission', 'possession', 'profession', 'provision', 'revision', 'session', 'submission', 'suspension', 'television', 'tension', 'transmission', 'version', 'vision'];
  static const List<String> _lesson120Words = ['adventure', 'agriculture', 'architecture', 'capture', 'creature', 'culture', 'departure', 'feature', 'fixture', 'fracture', 'furniture', 'future', 'gesture', 'lecture', 'literature', 'manufacture', 'mature', 'mixture', 'moisture', 'nature', 'pasture', 'picture', 'posture', 'puncture', 'rapture', 'rupture', 'sculpture', 'signature', 'structure', 'temperature', 'texture', 'torture', 'venture', 'vulture'];
  static const List<String> _lesson121ErWords = ['baker', 'banker', 'barber', 'batter', 'builder', 'camper', 'catcher', 'cleaner', 'climber', 'dancer', 'dealer', 'dreamer', 'driver', 'farmer', 'fighter', 'fisher', 'golfer', 'helper', 'hunter', 'jumper', 'keeper', 'leader', 'learner', 'maker', 'miner', 'painter', 'pitcher', 'player', 'plumber', 'printer', 'racer', 'reader', 'rider', 'runner', 'sailor', 'seller', 'sender', 'singer', 'speaker', 'starter', 'swimmer', 'teacher', 'thinker', 'trader', 'trainer', 'walker', 'winner', 'worker', 'writer'];
  static const List<String> _lesson121IstWords = ['artist', 'bassist', 'biologist', 'botanist', 'chemist', 'cyclist', 'dentist', 'finalist', 'florist', 'guitarist', 'journalist', 'linguist', 'novelist', 'optimist', 'organist', 'pianist', 'scientist', 'specialist', 'stylist', 'tourist', 'violinist'];
  static const List<String> _lesson124Words = ['awareness', 'blindness', 'boldness', 'brightness', 'business', 'calmness', 'careless', 'cleverness', 'coldness', 'coolness', 'darkness', 'deafness', 'fairness', 'fitness', 'fondness', 'foolishness', 'freshness', 'fullness', 'goodness', 'greatness', 'happiness', 'hardness', 'harness', 'helpless', 'homeless', 'hopeless', 'illness', 'kindness', 'lateness', 'laziness', 'lightness', 'likeness', 'loneliness', 'loudness', 'madness', 'meanness', 'nameless', 'nearness', 'neatness', 'newness', 'numbness', 'openness', 'painless', 'paleness', 'politeness', 'poorness', 'quickness', 'quietness', 'readiness', 'richness', 'sadness', 'selfishness', 'sharpness', 'sickness', 'slowness', 'smoothness', 'softness', 'soreness', 'soundness', 'stiffness', 'stillness', 'sweetness', 'thickness', 'thinness', 'tightness', 'tiredness', 'useless', 'weakness', 'wellness', 'wetness', 'wilderness', 'witness', 'worthless'];
  static const List<String> _lesson125Words = ['achievement', 'adjustment', 'advertisement', 'agreement', 'amusement', 'announcement', 'apartment', 'appointment', 'argument', 'arrangement', 'assessment', 'assignment', 'attachment', 'basement', 'commitment', 'complement', 'department', 'development', 'disappointment', 'document', 'element', 'employment', 'encouragement', 'engagement', 'enjoyment', 'enrollment', 'entertainment', 'environment', 'equipment', 'establishment', 'excitement', 'experiment', 'government', 'improvement', 'instrument', 'investment', 'involvement', 'judgment', 'management', 'measurement', 'monument', 'movement', 'payment', 'placement', 'punishment', 'replacement', 'requirement', 'retirement', 'settlement', 'shipment', 'statement', 'supplement', 'tournament', 'treatment'];
  static const List<String> _lesson126Words = ['acceptable', 'accessible', 'admirable', 'adorable', 'affordable', 'agreeable', 'allowable', 'applicable', 'available', 'believable', 'capable', 'changeable', 'comfortable', 'comparable', 'considerable', 'credible', 'dependable', 'desirable', 'durable', 'edible', 'eligible', 'enjoyable', 'excitable', 'favorable', 'flexible', 'forgettable', 'horrible', 'incredible', 'invisible', 'irritable', 'laughable', 'legible', 'likeable', 'manageable', 'miserable', 'moveable', 'notable', 'observable', 'payable', 'portable', 'possible', 'predictable', 'probable', 'profitable', 'readable', 'reasonable', 'recyclable', 'reliable', 'removable', 'renewable', 'respectable', 'responsible', 'reversible', 'sensible', 'suitable', 'terrible', 'tolerable', 'understandable', 'unforgettable', 'valuable', 'variable', 'visible', 'washable', 'workable'];
  
  // Prefixes
  static const List<String> _lesson104Words = ['precook', 'precut', 'predict', 'prefer', 'pregame', 'preheat', 'prejudge', 'premade', 'prepare', 'preschool', 'preset', 'pretest', 'preview', 'reappear', 'rebuild', 'recall', 'recapture', 'recharge', 'reclaim', 'recount', 'recover', 'recycle', 'redo', 'redraw', 'refill', 'refresh', 'refund', 'reheat', 'rejoin', 'remake', 'remind', 'remove', 'rename', 'renew', 'reopen', 'reorder', 'repaint', 'repair', 'repeat', 'replace', 'replay', 'report', 'reprint', 'reread', 'resell', 'reset', 'restart', 'restate', 'restore', 'retake', 'rethink', 'return', 'reuse', 'review', 'revise', 'rewind', 'rewrite'];
  static const List<String> _lesson105Words = ['disable', 'disagree', 'disappear', 'disappoint', 'disapprove', 'disarm', 'disarray', 'disbelief', 'discard', 'discharge', 'disclose', 'discolor', 'discomfort', 'disconnect', 'discontinue', 'discount', 'discourage', 'discover', 'discuss', 'disease', 'disgrace', 'disguise', 'disgust', 'dishonest', 'disinfect', 'dislike', 'dislocate', 'dismiss', 'dismount', 'disobey', 'disorder', 'disorganize', 'disown', 'displace', 'display', 'displease', 'disqualify', 'disregard', 'disrespect', 'disrupt', 'dissatisfy', 'distaste', 'distract', 'distress', 'distrust', 'disturb'];
  static const List<String> _lesson127Words = ['unicorn', 'unicycle', 'uniform', 'unify', 'union', 'unique', 'unison', 'unit', 'unite', 'unity', 'universal', 'universe', 'university', 'bicycle', 'bicep', 'bicolor', 'biennial', 'bifocal', 'bilateral', 'bilingual', 'bimonthly', 'binary', 'binoculars', 'biography', 'biology', 'biplane', 'bipolar', 'biracial', 'biweekly', 'triangle', 'triceps', 'tricolor', 'tricycle', 'trident', 'triennial', 'trifold', 'trilogy', 'trio', 'triple', 'triplet', 'tripod', 'trisect'];

  // Helper function to get word grid from lesson ID
  static List<List<String>> getLessonWordGrid(String lessonId) {
    List<String> words = [];
    
    // Find the words for this lesson ID
    switch (lessonId) {
      // Kindergarten lessons
      case 'lesson_13': words = _lesson13Words; break;
      case 'lesson_14': words = _lesson14Words; break;
      case 'lesson_15': words = _lesson15Words; break;
      case 'lesson_16': words = _lesson16Words; break;
      case 'lesson_17': words = _lesson17Words; break;
      case 'lesson_18': words = _lesson18Words; break;
      case 'lesson_35a': words = _lesson35aWords; break;
      case 'lesson_35c': words = _lesson35cWords; break;
      case 'lesson_36a': words = _lesson36aWords; break;
      case 'lesson_36b': words = _lesson36bWords; break;
      case 'lesson_37a': words = _lesson37aWords; break;
      case 'lesson_39a': words = _lesson39aWords; break;
      case 'lesson_40a': words = _lesson40aWords; break;
      case 'lesson_45': words = _lesson45Words; break;
      case 'lesson_46': words = _lesson46Words; break;
      case 'lesson_48': words = _lesson48Words; break;
      case 'lesson_49': words = _lesson49Words; break;
      case 'lesson_51': words = _lesson51Words; break;
      case 'lesson_65': words = _lesson65Words; break;
      case 'lesson_67a': words = _lesson67aWords; break;
      case 'lesson_68': words = _lesson68Words; break;
      
      // First grade lessons
      case 'lesson_41b_1st': words = _lesson41bWords; break;
      case 'lesson_43_1st': words = _lesson43Words; break;
      case 'lesson_53_1st': words = _lesson53Words; break;
      case 'lesson_77': words = _lesson77Words; break;
      case 'lesson_78': words = _lesson78Words; break;
      case 'lesson_80': words = _lesson80Words; break;
      case 'lesson_81': words = _lesson81Words; break;
      case 'lesson_83': words = _lesson83Words; break;
      case 'lesson_84_ai': words = _lesson84AiWords; break;
      case 'lesson_84_ay': words = _lesson84AyWords; break;
      case 'lesson_85_ea': words = _lesson85EaWords; break;
      case 'lesson_85_ee': words = _lesson85EeWords; break;
      case 'lesson_86_oa': words = _lesson86OaWords; break;
      case 'lesson_90': words = _lesson90Words; break;
      case 'lesson_95': words = _lesson95Words; break;
      case 'lesson_96_ou': words = _lesson96OuWords; break;
      case 'lesson_96_ow': words = _lesson96OwWords; break;
      case 'lesson_100': words = _lesson100Words; break;
      case 'lesson_101': words = _lesson101Words; break;
      case 'lesson_103': words = _lesson103Words; break;
      case 'lesson_107_ed': words = _lesson107EdWords; break;
      case 'lesson_109': words = _lesson109Words; break;
      
      // Second grade lessons
      case 'lesson_38a_2nd': words = _lesson38aWords; break;
      case 'lesson_88': words = _lesson88Words; break;
      case 'lesson_97': words = _lesson97Words; break;
      case 'lesson_111': words = _lesson111Words; break;
      case 'lesson_112': words = _lesson112Words; break;
      case 'lesson_113': words = _lesson113Words; break;
      case 'lesson_119_tion': words = _lesson119TionWords; break;
      case 'lesson_119_sion': words = _lesson119SionWords; break;
      case 'lesson_120': words = _lesson120Words; break;
      case 'lesson_121_er': words = _lesson121ErWords; break;
      case 'lesson_121_ist': words = _lesson121IstWords; break;
      case 'lesson_124': words = _lesson124Words; break;
      case 'lesson_125': words = _lesson125Words; break;
      case 'lesson_126': words = _lesson126Words; break;
      case 'lesson_104': words = _lesson104Words; break;
      case 'lesson_105': words = _lesson105Words; break;
      case 'lesson_127': words = _lesson127Words; break;
      
      default: words = [];
    }
    
    if (words.isEmpty) return [];
    
    // Create grid from words
    return _createGrid(words);
  }
  
  static List<List<String>> _createGrid(List<String> words) {
    final shuffled = List<String>.from(words)..shuffle();
    final gridWords = <String>[];
    
    // Fill to 36 words
    while (gridWords.length < 36) {
      for (final word in shuffled) {
        if (gridWords.length >= 36) break;
        gridWords.add(word);
      }
    }
    
    // Create 6x6 grid
    final grid = <List<String>>[];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        row.add(gridWords[i * 6 + j]);
      }
      grid.add(row);
    }
    
    return grid;
  }
}