# Template for ~/.config/secrets.env — rendered from 1Password via `op inject`.
#
# Render with:  secrets-render
# fish then auto-loads ~/.config/secrets.env at startup.
#
# CAUTION: `op inject` resolves every 1Password reference token in this file,
# even on lines starting with '#'. So this file must contain ONLY references you
# actually want fetched -- do not write commented-out example references (or even
# the bare scheme in prose), or the render fails. That is why this header avoids
# writing the scheme literally.
#
# To add a provider, add:   VARNAME=<ref>
#   where <ref> is the 1Password reference: scheme + vault/item/field.
#   - API_CREDENTIAL items expose the key in the `credential` field.
#   - Use the item's stable ID instead of its title if the title is duplicated
#     or contains a "/".   Discover items with:  op item list

ANTHROPIC_API_KEY=op://Private/Anthropic API/credential
OPENAI_API_KEY=op://Private/OpenAI API/credential
GEMINI_API_KEY=op://Private/Gemini API/credential
GOOGLE_GENERATIVE_AI_API_KEY=op://Private/Gemini API/credential
OPENROUTER_API_KEY=op://Private/bcngp2zna3q2e7x57qheoizxjy/credential
INCEPTION_API_KEY=op://Private/gj346tf5xg4huwywtficjajeli/credential
