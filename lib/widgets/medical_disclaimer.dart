import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/app_localizations.dart';

/// Which clinical surface the disclaimer is attached to.
///
/// Each surface makes a slightly different implicit claim, so each gets a
/// different sentence rather than one generic paragraph that nobody reads.
enum DisclaimerContext {
  /// Vitals: the app colours readings red/amber/green.
  vitals,

  /// Medications: schedules, doses and reminders.
  medication,

  /// Health articles and educational content.
  article,

  /// Generated clinical documents (handover report).
  report,
}

/// A quiet, persistent note that this app does not practise medicine.
///
/// WHY THIS EXISTS
/// Before round 4 the app carried no medical disclaimer anywhere — the only
/// one in the codebase was a sentence inside the body text of a single blog
/// article. Meanwhile the app renders a patient's SpO2 in RED, tells a family
/// a reading is "outside safe range", schedules and reminds on prescription
/// drugs, and generates a doctor handover document. Those are clinical
/// presentations, and presenting them with no stated limits invites a family
/// to treat a green dot as clearance and a missing alert as reassurance.
///
/// DESIGN INTENT — modest on purpose
/// This is a footer note, never a modal and never a blocking gate. A
/// disclaimer a person must dismiss to see their mother's oxygen level trains
/// them to dismiss it, and a legal shield nobody reads protects nobody. It
/// reads as guidance to act on ("tell your nurse"), not as a liability
/// notice — that is also the only version a worried family will actually
/// take in.
///
/// It is NEVER shown on the SOS path. Nothing may add friction or hesitation
/// there.
class MedicalDisclaimer extends StatelessWidget {
  final DisclaimerContext context_;
  final EdgeInsetsGeometry padding;

  const MedicalDisclaimer({
    super.key,
    required this.context_,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  /// Last-resort English copy, used only when localization is unavailable.
  ///
  /// This is NOT a way around the i18n rule — every string here also has a key
  /// in both en.json and hi.json, and [_key] is the normal path. It exists
  /// because the first version of this widget called
  /// `AppLocalizations.of(context)!` and the article screen's test caught it
  /// throwing: the delegate resolves asynchronously, so during the frames
  /// before it lands `of(context)` is null and the `!` took down the entire
  /// screen the disclaimer was meant to caption.
  ///
  /// A safety notice that can crash the page it sits on is worse than no
  /// notice, so this degrades instead: correct English text, then the
  /// localized string as soon as it is available.
  static const Map<DisclaimerContext, String> _fallback = {
    DisclaimerContext.vitals:
        'These readings and their colours are a guide, not a diagnosis. If '
            'something looks wrong, or the person feels unwell whatever the '
            'colour says, tell your nurse or health manager straight away.',
    DisclaimerContext.medication:
        'This schedule reflects what has been recorded for this patient. It '
            'is not a prescription and reminders can be missed. Only a doctor '
            'may start, stop or change a medicine or its dose.',
    DisclaimerContext.article:
        'General information, not advice for any one person. Talk to your '
            'doctor or your Housepital health manager before acting on '
            'anything here.',
    DisclaimerContext.report:
        'Prepared from records entered in the Housepital app. It is a '
            'summary for your doctor, not a clinical assessment, and it may '
            'be incomplete.',
  };

  String _key() {
    switch (context_) {
      case DisclaimerContext.vitals:
        return 'disclaimer_vitals';
      case DisclaimerContext.medication:
        return 'disclaimer_medication';
      case DisclaimerContext.article:
        return 'disclaimer_article';
      case DisclaimerContext.report:
        return 'disclaimer_report';
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _key();
    final l = AppLocalizations.of(context);
    // `t` returns the KEY itself when a translation is missing, which would
    // render "disclaimer_vitals" to a worried family. Treat that as missing
    // too and fall back to real prose.
    final localized = l?.t(key);
    final text = (localized == null || localized == key)
        ? _fallback[context_]!
        : localized;

    return Padding(
      padding: padding,
      child: Semantics(
        // Read as one unit, and labelled so a screen-reader user knows this is
        // a limitation notice rather than another data row.
        label: 'Important note: $text',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: context.hc.greyLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: context.hc.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
