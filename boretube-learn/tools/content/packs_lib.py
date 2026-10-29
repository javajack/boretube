"""Item builders shared by packs.py and more.py."""


def skill(sid, title, outcome, badge, formats, items):
    return dict(id=sid, title=title, outcome=outcome, badge=badge, formats=formats, items=items)


def it(iid, q, options, why, picture=None, fact=None):
    d = dict(id=iid, q=q, options=options, answer=0, explain=why)
    if picture:
        d["picture"] = picture
    if fact:
        d["fact"] = fact
    return d


def first_letter(word, pic, wrong):
    return it(word, "Which letter does this start with?", [word[0].upper()] + wrong,
              f"{word.capitalize()} starts with {word[0].upper()}: {'-'.join(word)}.", pic,
              fact=f"{word.capitalize()} starts with {word[0].upper()}")


def picture_word(word, wrong):
    return it(word, "Which word is this?", [word] + wrong, f"This is a {word}.", word, fact=f"This is a {word}")


def pic_q(iid, q, right, wrong, why):
    return it(iid, q, [f"pic:{right}"] + [f"pic:{w}" for w in wrong], why, fact=f"The {right}")
