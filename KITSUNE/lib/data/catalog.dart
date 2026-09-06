class CatalogField {
  const CatalogField({
    required this.id,
    required this.label,
    required this.category,
    required this.categoryTitle,
    required this.type,
    this.unit,
  });

  final String id;
  final String label;
  final String category;
  final String categoryTitle;
  final String type;
  final String? unit;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'category': category,
        'categoryTitle': categoryTitle,
        'type': type,
        if (unit != null) 'unit': unit,
      };
}

String _label(String id) =>
    id.replaceAll('_', ' ').replaceAllMapped(RegExp(r'\b[a-z]'), (m) => m[0]!.toUpperCase());

String _type(String id) {
  final s = id.toLowerCase();
  if (s.contains('date') || s.contains('last_period') || s.contains('onset')) return 'date';
  if (RegExp(r'age|hours|percent|weight|length|girth|pitch|circumference|ratio|bmi|dose|testosterone|estradiol|progesterone|prolactin|hemoglobin|hematocrit|quantity|size|band|cup').hasMatch(s)) {
    return 'number';
  }
  if (s.contains('history') || s.contains('notes') || s.contains('plans') || s.contains('goals') || s.contains('preferences')) {
    return 'text';
  }
  if (s.startsWith('previous') || s.contains('whether') || s.contains('halted') || s.contains('interest')) {
    return 'text';
  }
  return 'rating';
}

List<CatalogField> _pack(String category, String title, List<String> ids) {
  return [
    for (final id in ids)
      CatalogField(
        id: '${category}__$id',
        label: _label(id),
        category: category,
        categoryTitle: title,
        type: _type(id),
      ),
  ];
}

class FieldCatalog {
  static List<CatalogField> forProfile(String profile) {
    if (profile == 'trans_women') return transWomen;
    return transMen;
  }

  static CatalogField? byId(String profile, String id) {
    try {
      return forProfile(profile).firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  static Map<String, List<CatalogField>> grouped(String profile) {
    final map = <String, List<CatalogField>>{};
    for (final f in forProfile(profile)) {
      map.putIfAbsent(f.category, () => []).add(f);
    }
    return map;
  }

  static final transMen = <CatalogField>[
    ..._pack('hrt_timeline_and_testosterone_exposure', 'HRT timeline & testosterone', [
      'assigned_sex_at_birth', 'current_age', 'age_when_testosterone_began', 'exact_testosterone_start_date',
      'total_time_on_testosterone', 'first_noticeable_change', 'voice_change_date', 'first_facial_hair',
      'body_hair_onset', 'endogenous_puberty', 'puberty_progression', 'previous_blockers', 'blocker_age',
      'blocker_duration', 'time_between_blockers_and_testosterone', 'current_testosterone_dose', 'formulation',
      'route', 'injection_frequency', 'topical_frequency_and_location', 'oral_frequency', 'time_at_current_dose',
      'highest_dose', 'lowest_dose', 'complete_dose_change_history', 'seasonal_adjustment',
      'pharmacy_or_source_changes', 'compounded_or_commercial', 'previous_preparations', 'adherence',
      'missed_doses', 'catch_up_dosing', 'injection_day', 'time_since_injection_at_labs', 'peak_trough_pattern',
      'formulation_changes', 'sustained_release_implants', 'implant_replacement_frequency',
      'most_recent_hormone_panel', 'total_testosterone', 'free_testosterone', 'estradiol', 'progesterone',
      'testosterone_trend', 'estradiol_trend', 'lab_timing', 'prolactin', 'shbg', 'thyroid_function',
      'liver_function_markers',
    ]),
    ..._pack('reproductive_and_genital', 'Reproductive & genital', [
      'clitoral_development', 'baseline_length', 'current_length', 'baseline_girth', 'current_girth', 'firmness',
      'sensitivity', 'erectile_capacity', 'growth_start', 'estimated_growth_rate', 'growth_trend', 'pigmentation',
      'retraction_or_exposure', 'external_positioning', 'vaginal_atrophy', 'dryness', 'tissue_appearance',
      'cervical_changes', 'cramping', 'ovarian_function', 'menstrual_changes', 'breakthrough_bleeding',
      'last_period', 'fertility_status_or_concerns', 'egg_freezing', 'future_genetic_parenthood_interest',
      'reproductive_tissue_procedures', 'pelvic_floor_changes', 'internal_tissue_changes', 'urinary_changes',
      'urinary_stream', 'metoidioplasty_candidacy_tracking', 'phalloplasty_interest', 'erectile_response_changes',
      'arousal_timing', 'orgasm_changes',
    ]),
    ..._pack('body_composition', 'Body composition', [
      'height', 'pre_testosterone_weight', 'current_weight', 'three_month_trend', 'twelve_month_trend', 'bmi',
      'body_fat_percentage', 'target_body_fat_percentage', 'weight_distribution_goals', 'hip_circumference',
      'waist_circumference', 'chest_circumference', 'bust_circumference', 'hip_to_waist_ratio',
      'shoulder_to_hip_ratio', 'body_shape_perception', 'visceral_fat', 'subcutaneous_fat',
      'breast_or_chest_tissue_changes', 'regional_fat_changes', 'face_fat_redistribution', 'extremity_changes',
      'abdominal_changes', 'neck_circumference', 'thigh_circumference', 'calf_circumference', 'bicep_circumference',
      'shoulder_circumference', 'torso_length', 'lean_mass', 'water_percentage', 'bone_mass', 'waist_trend',
      'hip_trend', 'chest_trend', 'posture', 'clothing_size_chest', 'clothing_size_waist', 'clothing_size_hips',
      'overall_body_satisfaction',
    ]),
    ..._pack('muscle_and_physiology', 'Muscle & physiology', [
      'muscle_mass', 'gain_rate', 'first_noticeable_gain', 'growth_trend', 'upper_body_definition',
      'lower_body_definition', 'shoulders', 'arms', 'legs', 'abdomen', 'chest', 'back', 'grip_strength',
      'lifting_capacity', 'recovery', 'exercise_tolerance', 'soreness', 'pre_testosterone_voice_pitch',
      'current_pitch', 'voice_change_timeline', 'depth', 'range', 'cracking_period', 'stability', 'voice_training',
      'laryngeal_prominence', 'dysphoria', 'speech_pattern', 'resonance', 'breathiness', 'rasp', 'vocal_endurance',
      'strength', 'cardiovascular_endurance', 'hemoglobin', 'hematocrit', 'rbc_changes', 'metabolism',
      'cold_tolerance', 'heat_tolerance', 'sweating', 'sweat_odor', 'body_temperature_baseline',
    ]),
    ..._pack('hair', 'Hair', [
      'baseline_facial_hair', 'facial_hair_density', 'facial_hair_color', 'facial_hair_texture',
      'facial_hair_coverage', 'facial_hair_growth_rate', 'facial_hair_growth_trend', 'facial_hair_satisfaction',
      'sideburns', 'upper_lip', 'chin', 'cheeks', 'facial_neck', 'previous_hair_removal',
      'baseline_body_hair_coverage', 'current_body_hair_density', 'body_hair_color', 'body_hair_texture',
      'body_arms', 'body_legs', 'body_chest', 'body_abdomen', 'body_back', 'body_face', 'genital_region_hair',
      'body_hair_growth_rate', 'body_hair_growth_trend', 'scalp_baseline_density', 'scalp_current_density',
      'hair_loss', 'scalp_texture', 'oil_production', 'male_pattern_baldness', 'recession', 'thickness',
      'scalp_color', 'graying', 'styling_preferences',
    ]),
    ..._pack('facial_features', 'Facial features', [
      'jaw_prominence', 'jawline_definition', 'chin_size', 'chin_projection', 'cheekbones', 'cheek_fat',
      'forehead', 'brow_ridge', 'eye_area', 'under_eye_area', 'lips', 'mouth_width', 'nose_appearance',
      'nasal_bridge', 'nostrils', 'face_width', 'face_length', 'overall_masculinization', 'effect_of_facial_hair',
      'face_shape', 'skin_texture', 'skin_thickness', 'acne', 'oiliness', 'pore_size',
    ]),
    ..._pack('voice', 'Voice & communication', [
      'voice_dysphoria', 'gendering_on_phone', 'gendering_in_person', 'voice_training', 'voice_confidence',
      'training_hours', 'perceived_voice', 'communication_changes', 'speech_confidence', 'formal_voice_classes',
    ]),
    ..._pack('surgery_and_fertility', 'Surgery & fertility', [
      'hysterectomy_plans', 'oophorectomy_plans', 'metoidioplasty_plans', 'phalloplasty_plans',
      'vaginectomy_plans', 'surgical_timelines', 'fertility_preservation', 'egg_freezing',
      'chest_masculinization_plans', 'surgical_recovery_notes',
    ]),
  ];

  static final transWomen = <CatalogField>[
    ..._pack('facial_feminization', 'Facial feminization', [
      'baseline_facial_fat_distribution', 'current_distribution', 'cheek_fat_accumulation', 'cheekbone_prominence',
      'jawline', 'jaw_softness', 'jaw_angle_perception', 'chin_size', 'chin_projection', 'chin_prominence',
      'chin_shape', 'forehead_appearance', 'brow_ridge', 'supraorbital_fat', 'under_eye_area', 'under_eye_fullness',
      'eye_area_feminization', 'orbital_fat', 'eyelid_appearance', 'crows_feet', 'nasal_fat',
      'nose_soft_tissue_appearance', 'nostril_appearance', 'lip_fullness', 'lip_projection', 'lip_color',
      'mouth_width', 'mouth_shape', 'oral_commissures', 'lip_to_chin_distance', 'philtrum', 'skin_texture',
      'smoothness', 'elasticity', 'skin_evenness', 'oiliness', 'acne', 'rosacea_redness', 'skin_tightness',
      'laxity', 'facial_swelling_timeline', 'temple_hollowing', 'malar_bags', 'nasolabial_folds', 'marionette_lines',
    ]),
    ..._pack('hair', 'Hair', [
      'scalp_baseline_density', 'scalp_current_density', 'loss_or_regrowth', 'regrowth_rate', 'whether_hair_loss_halted',
      'regrowth_in_thinning_areas', 'scalp_texture', 'curl_wave_changes', 'strand_thickness', 'color', 'graying',
      'styling_options', 'body_baseline_coverage', 'body_current_density', 'regression_timeline', 'arms', 'legs',
      'chest', 'abdomen', 'back', 'face', 'hands', 'feet', 'body_color', 'body_texture', 'removal_history',
      'current_removal_requirements', 'regression_rate', 'facial_baseline_density', 'facial_current_density',
      'facial_growth_rate', 'facial_color', 'growth_slowing', 'complete_cessation', 'lightening', 'fineness',
      'removal_frequency', 'removal_method', 'dysphoria', 'sideburns', 'upper_lip', 'chin', 'cheeks', 'neck',
    ]),
    ..._pack('skin', 'Skin', [
      'baseline_texture', 'current_texture', 'improvement_timeline', 'rough_areas', 'skin_tone_changes', 'dryness',
      'oiliness', 'ph_if_measured', 'moisture_retention', 'acne_severity', 'acne_location', 'acne_improvement_timeline',
      'scarring', 'sensitivity', 'rosacea', 'inflammation', 'elasticity_collagen_appearance', 'fine_lines',
      'pore_size', 'pore_visibility', 'luminosity', 'cellulite', 'stretch_marks', 'provider_measured_skin_thickness',
      'feminine_feeling_skin_perception', 'moisturizer_needs', 'skincare_effectiveness',
    ]),
    ..._pack('voice', 'Voice', [
      'pre_hrt_pitch', 'current_pitch', 'pitch_changes', 'resonance', 'current_resonance', 'laryngoscopy_findings',
      'laryngeal_prominence', 'voice_training', 'range', 'breath_support', 'strength', 'endurance', 'hoarseness',
      'breathiness', 'voice_dysphoria', 'communication_style', 'speech_patterns', 'confidence',
      'appearance_related_voice_perception', 'voice_therapy_hours',
    ]),
    ..._pack('body_and_physiology', 'Body & physiology', [
      'baseline_muscle', 'current_muscle', 'atrophy_rate', 'upper_body_strength', 'lower_body_strength',
      'grip_strength', 'recovery', 'exercise_tolerance', 'fatigue', 'energy', 'fat_distribution', 'weight',
      'weight_pattern', 'hip_circumference', 'hip_growth', 'waist', 'waist_hip_ratio', 'thighs', 'buttocks',
      'breast_body_fat_ratio', 'abdominal_distribution', 'feminine_fat_pattern_development', 'body_temperature',
      'cold_tolerance', 'heat_tolerance', 'sweating', 'sweat_odor', 'body_odor', 'circulation',
      'metabolic_rate_perception', 'caloric_needs', 'shoulder_softening', 'muscle_definition_loss', 'joint_flexibility',
    ]),
    ..._pack('breast_development', 'Breast development', [
      'areola_color', 'areola_size', 'areola_shape', 'nipple_projection', 'nipple_sensation', 'nipple_erections',
      'tissue_density', 'fibrous_development', 'glandular_development', 'firmness', 'pectoral_muscle_baseline',
      'current_pectoral_prominence', 'visibility_through_breast_tissue', 'stretch_marks', 'stretch_mark_color',
      'breast_skin', 'pigmentation', 'veins', 'postural_changes', 'shoulder_back_strain', 'bra_fit',
      'bra_size_timeline', 'band_size', 'cup_size', 'dysphoria_changes', 'asymmetry', 'left_right_volume',
      'asymmetry_improvement', 'cyclical_sensitivity', 'swelling', 'axillary_breast_tissue', 'inframammary_fold',
      'fold_depth', 'tanner_stage',
    ]),
    ..._pack('secondary_sexual_characteristics', 'Secondary characteristics', [
      'overall_body_shape', 'current_body_shape', 'hourglass_development', 'soft_tissue_pelvic_appearance',
      'hip_padding', 'thigh_gap', 'thigh_shape', 'calf_shape', 'ankles', 'hands', 'fingers', 'feet',
      'overall_contour', 'symmetry', 'shoulder_width_perception', 'rib_cage_appearance', 'waist_definition',
      'torso_curvature', 'buttock_projection', 'desired_silhouette',
    ]),
    ..._pack('genital_and_sexual', 'Genital & sexual', [
      'baseline_genital_dysphoria', 'current_dysphoria', 'testicular_size', 'atrophy', 'firmness', 'erectile_function',
      'spontaneous_erections', 'libido', 'current_libido', 'libido_timeline', 'sex_drive', 'orgasm_changes',
      'orgasm_intensity', 'pleasure_patterns', 'genital_sensation', 'gender_affirmation', 'tucking_needs',
      'intimacy_confidence', 'genital_surgery_consideration', 'surgery_timeline',
    ]),
  ];
}
