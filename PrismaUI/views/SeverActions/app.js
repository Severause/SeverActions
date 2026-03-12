/* =============================================================================
 * SeverActions PrismaUI Config Menu — Application Logic
 *
 * Communication:
 *   C++ -> JS: InteropCall invokes window[funcName](arg)
 *   JS -> C++: RegisterJSListener binds functions JS can call
 * ============================================================================= */

'use strict';

// =============================================================================
// PrismaUI Interop Layer
// =============================================================================

const Interop = {
    /** Call a C++ registered listener (JS -> C++) */
    call(funcName, arg) {
        const strArg = typeof arg === 'string' ? arg : JSON.stringify(arg || '');
        if (typeof window[funcName] === 'function') {
            window[funcName](strArg);
        }
    },

    /** Register a function that C++ can invoke via InteropCall (C++ -> JS) */
    register(funcName, fn) {
        window[funcName] = fn;
    }
};

// =============================================================================
// Application State
// =============================================================================

const State = {
    activePage: 'general',
    pageData: {},
    pageLoaded: {},
    pendingConfirm: null,
    selectedCompanionIdx: 0,
    selectedOutfitNPCIdx: 0
};

// =============================================================================
// Constants
// =============================================================================

const BOOK_READ_MODES = ['Read Aloud (Verbatim)', 'Summarize & React'];
const TARGET_MODES = ['Crosshair Target', 'Nearest NPC', 'Last Talked To'];
const COMBAT_STYLES = ['balanced', 'aggressive', 'defensive', 'ranged', 'healer'];
const FRAMEWORK_MODES = ['Auto', 'SeverActions Only', 'Tracking Only'];

const HOLD_NAMES = [
    'Eastmarch', 'Falkreath', 'Haafingar', 'Hjaalmarch',
    'The Pale', 'The Reach', 'The Rift', 'Whiterun', 'Winterhold'
];

// DX Scan Code -> readable key name
const KEY_NAMES = {
    '-1':'Not Set','0':'Not Set','1':'ESC','2':'1','3':'2','4':'3','5':'4',
    '6':'5','7':'6','8':'7','9':'8','10':'9','11':'0','12':'-','13':'=',
    '14':'Backspace','15':'Tab','16':'Q','17':'W','18':'E','19':'R','20':'T',
    '21':'Y','22':'U','23':'I','24':'O','25':'P','26':'[','27':']',
    '28':'Enter','29':'L Ctrl','30':'A','31':'S','32':'D','33':'F','34':'G',
    '35':'H','36':'J','37':'K','38':'L','39':';','40':"'",'41':'`',
    '42':'L Shift','43':'\\','44':'Z','45':'X','46':'C','47':'V','48':'B',
    '49':'N','50':'M','51':',','52':'.','53':'/','54':'R Shift','55':'Num *',
    '56':'L Alt','57':'Space','58':'Caps Lock','59':'F1','60':'F2','61':'F3',
    '62':'F4','63':'F5','64':'F6','65':'F7','66':'F8','67':'F9','68':'F10',
    '69':'Num Lock','70':'Scroll Lock','71':'Num 7','72':'Num 8','73':'Num 9',
    '74':'Num -','75':'Num 4','76':'Num 5','77':'Num 6','78':'Num +',
    '79':'Num 1','80':'Num 2','81':'Num 3','82':'Num 0','83':'Num .',
    '87':'F11','88':'F12','156':'Num Enter','157':'R Ctrl','181':'Num /',
    '183':'PrtSc','184':'R Alt','197':'Pause','199':'Home','200':'Up',
    '201':'PgUp','203':'Left','205':'Right','207':'End','208':'Down',
    '209':'PgDn','210':'Insert','211':'Delete',
    '256':'LMB','257':'RMB','258':'MMB','259':'Mouse4','260':'Mouse5'
};

function getKeyName(code) {
    return KEY_NAMES[String(code)] || (code > 0 ? 'Key ' + code : 'Not Set');
}

// =============================================================================
// Utility Functions
// =============================================================================

function escHtml(str) {
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
}

function formatSliderValue(val, fmt) {
    if (!fmt) return String(val);
    if (fmt.includes('{0}')) return fmt.replace('{0}', Math.round(val));
    if (fmt.includes('{1}')) return fmt.replace('{1}', parseFloat(val).toFixed(1));
    if (fmt.includes('{2}')) return fmt.replace('{2}', parseFloat(val).toFixed(2));
    return String(val);
}

function safeParseJson(str) {
    try { return JSON.parse(str); }
    catch (e) { console.error('JSON parse error:', e); return null; }
}

// =============================================================================
// Tab Switching
// =============================================================================

function switchTab(pageName) {
    if (pageName === State.activePage) return;

    document.querySelectorAll('.tab').forEach(t =>
        t.classList.toggle('active', t.dataset.page === pageName));
    document.querySelectorAll('.page').forEach(p =>
        p.classList.toggle('active', p.id === 'page-' + pageName));

    State.activePage = pageName;
    requestPageData(pageName);
}

function requestPageData(pageName) {
    const page = document.getElementById('page-' + pageName);
    if (page && !State.pageLoaded[pageName]) {
        page.innerHTML = '<div class="loading">Loading...</div>';
    }
    Interop.call('requestPageData', pageName);
}

// =============================================================================
// Reusable Control Builders
// =============================================================================

function sectionHeader(title) {
    return '<div class="section-header">' + escHtml(title) + '</div>';
}

function infoRow(label, value) {
    return '<div class="info-row"><span class="label">' + escHtml(label) +
        '</span><span class="value">' + escHtml(String(value)) + '</span></div>';
}

function infoText(text) {
    return '<div class="info-text">' + escHtml(text) + '</div>';
}

function toggleControl(label, key, checked, page, tooltip, target) {
    const id = 'toggle-' + page + '-' + key;
    const tgt = target ? ' data-target="' + escHtml(target) + '"' : '';
    return '<div class="control-row"' +
        (tooltip ? ' title="' + escHtml(tooltip) + '"' : '') + '>' +
        '<span class="label">' + escHtml(label) + '</span>' +
        '<label class="toggle">' +
        '<input type="checkbox" id="' + id + '" data-key="' + key +
        '" data-page="' + page + '"' + tgt +
        (checked ? ' checked' : '') + ' class="setting-toggle">' +
        '<span class="toggle-slider"></span></label></div>';
}

function sliderControl(label, key, value, min, max, step, fmt, page, tooltip, target) {
    const id = 'slider-' + page + '-' + key;
    const tgt = target ? ' data-target="' + escHtml(target) + '"' : '';
    return '<div class="control-row"' +
        (tooltip ? ' title="' + escHtml(tooltip) + '"' : '') + '>' +
        '<span class="label">' + escHtml(label) + '</span>' +
        '<div class="slider-group">' +
        '<input type="range" class="slider setting-slider" id="' + id +
        '" data-key="' + key + '" data-page="' + page + '" data-format="' +
        (fmt || '') + '"' + tgt + ' min="' + min + '" max="' + max +
        '" step="' + step + '" value="' + value + '">' +
        '<span class="slider-value" id="' + id + '-val">' +
        formatSliderValue(value, fmt) + '</span></div></div>';
}

function dropdownControl(label, key, value, options, page, tooltip, target) {
    const id = 'dd-' + page + '-' + key;
    const tgt = target ? ' data-target="' + escHtml(target) + '"' : '';
    let opts = '';
    options.forEach(function(opt, i) {
        opts += '<option value="' + i + '"' + (i == value ? ' selected' : '') +
            '>' + escHtml(opt) + '</option>';
    });
    return '<div class="control-row"' +
        (tooltip ? ' title="' + escHtml(tooltip) + '"' : '') + '>' +
        '<span class="label">' + escHtml(label) + '</span>' +
        '<select class="dropdown setting-dropdown" id="' + id +
        '" data-key="' + key + '" data-page="' + page + '"' + tgt + '>' +
        opts + '</select></div>';
}

function hotkeyDisplay(label, key, keyCode) {
    return '<div class="control-row"><span class="label">' + escHtml(label) +
        '</span><div class="hotkey-btn" data-key="' + key +
        '" data-keycode="' + keyCode + '">' +
        escHtml(getKeyName(keyCode)) + '</div></div>';
}

function actionButton(label, action, extra, cssClass, confirmMsg) {
    let attrs = '';
    if (extra) {
        Object.keys(extra).forEach(function(k) {
            attrs += ' data-' + k + '="' + escHtml(String(extra[k])) + '"';
        });
    }
    return '<button class="btn ' + (cssClass || '') + '" data-action="' + action + '"' +
        attrs + (confirmMsg ? ' data-confirm="' + escHtml(confirmMsg) + '"' : '') +
        '>' + escHtml(label) + '</button>';
}

function barControl(label, value, min, max, colorClass) {
    var range = max - min;
    var pct = range > 0 ? Math.max(0, Math.min(100, ((value - min) / range) * 100)) : 0;
    return '<div class="bar-container"><span class="bar-label">' + escHtml(label) +
        '</span><div class="bar-track"><div class="bar-fill ' + (colorClass || 'neutral') +
        '" style="width:' + pct + '%"></div></div><span class="bar-value">' +
        value + '</span></div>';
}

// =============================================================================
// Page Rendering Dispatch
// =============================================================================

var PAGE_RENDERERS = {
    general: renderGeneralPage,
    hotkeys: renderHotkeysPage,
    currency: renderCurrencyPage,
    travel: renderTravelPage,
    bounty: renderBountyPage,
    survival: renderSurvivalPage,
    followers: renderFollowersPage,
    outfits: renderOutfitsPage
};

function renderPage(pageName, data) {
    var container = document.getElementById('page-' + pageName);
    if (!container) return;

    State.pageData[pageName] = data;
    State.pageLoaded[pageName] = true;

    var renderer = PAGE_RENDERERS[pageName];
    if (renderer) {
        container.innerHTML = renderer(data);
        bindPageControls(pageName, container);
    } else {
        container.innerHTML = '<div class="loading">Unknown page</div>';
    }
}

// =============================================================================
// Page Renderers
// =============================================================================

function renderGeneralPage(d) {
    var h = '<div class="section">' + sectionHeader('SeverActions Configuration') +
        infoRow('Version', d.version || '1.1') +
        infoRow('Author', d.author || 'Severause') +
        infoText('Configure SeverActions modules using the tabs above.') + '</div>';

    h += '<div class="section">' + sectionHeader('Native Features') +
        toggleControl('Dialogue Animations', 'dialogueAnimEnabled',
            d.dialogueAnimEnabled, 'general',
            'Enable conversation animations on NPCs during dialogue') +
        sliderControl('Silence Chance', 'silenceChance',
            d.silenceChance != null ? d.silenceChance : 50, 0, 100, 5,
            '{0}%', 'general',
            'Probability that silence is offered as a response option');
    if (d.hasLootScript) {
        h += dropdownControl('Book Reading Style', 'bookReadMode',
            d.bookReadMode != null ? d.bookReadMode : 0,
            BOOK_READ_MODES, 'general', 'How NPCs read books aloud');
    }
    h += '</div>';

    h += '<div class="section">' + sectionHeader('Speaker Tags') +
        toggleControl('[COMPANION] Tag', 'tagCompanion', d.tagCompanion, 'general',
            'Show the [COMPANION] tag in speaker selector') +
        toggleControl('[ENGAGED] Tag', 'tagEngaged', d.tagEngaged, 'general',
            'Show the [ENGAGED] tag in speaker selector') +
        toggleControl('[IN SCENE] Tag', 'tagInScene', d.tagInScene, 'general',
            'Show the [IN SCENE] tag in speaker selector') + '</div>';

    if (d.hasSpellTeachScript) {
        h += '<div class="section">' + sectionHeader('Spell Teaching') +
            toggleControl('Failure System', 'spellFailEnabled',
                d.spellFailEnabled, 'general', 'Enable spell learning failure system') +
            sliderControl('Failure Difficulty', 'spellFailDifficulty',
                d.spellFailDifficulty != null ? d.spellFailDifficulty : 1.0,
                0, 3, 0.1, '{1}x', 'general',
                'Multiplier for failure chance (0.5=easier, 2.0=harder)') + '</div>';
    }

    if (d.hasFollowerManager) {
        h += '<div class="section">' + sectionHeader('NPC Homes');
        var homes = d.npcHomes || [];
        if (homes.length === 0) {
            h += infoText('No custom homes assigned.');
        } else {
            homes.forEach(function(home, i) {
                h += '<div class="control-row">' +
                    '<span class="label">' + escHtml(home.name) +
                    ' &mdash; <span class="text-muted">' +
                    escHtml(home.location) + '</span></span>' +
                    actionButton('Clear', 'clearNPCHome',
                        { index: i, name: home.name }, 'btn-danger',
                        'Clear the custom home for ' + home.name + '?') + '</div>';
            });
        }
        h += '</div>';
    }

    return h;
}

function renderHotkeysPage(d) {
    var h = '<div class="section">' + sectionHeader('Wheel Menu') +
        hotkeyDisplay('Open Wheel Menu', 'wheelMenuKey',
            d.wheelMenuKey != null ? d.wheelMenuKey : -1) + '</div>';

    h += '<div class="section">' + sectionHeader('Follow System Hotkeys') +
        hotkeyDisplay('Toggle Follow', 'followToggleKey', d.followToggleKey || -1) +
        hotkeyDisplay('Dismiss Companion', 'dismissKey', d.dismissKey || -1) +
        hotkeyDisplay('Set Companion', 'setCompanionKey', d.setCompanionKey || -1) +
        hotkeyDisplay('Wait Here / Resume', 'companionWaitKey', d.companionWaitKey || -1) +
        hotkeyDisplay('Assign Home Here', 'assignHomeKey', d.assignHomeKey || -1) + '</div>';

    h += '<div class="section">' + sectionHeader('Furniture Hotkeys') +
        hotkeyDisplay('Make NPC Stand Up', 'standUpKey', d.standUpKey || -1) + '</div>';

    h += '<div class="section">' + sectionHeader('Combat Hotkeys') +
        hotkeyDisplay('Make NPC Yield', 'yieldKey', d.yieldKey || -1) + '</div>';

    h += '<div class="section">' + sectionHeader('Outfit Hotkeys') +
        hotkeyDisplay('Undress NPC', 'undressKey', d.undressKey || -1) +
        hotkeyDisplay('Dress NPC', 'dressKey', d.dressKey || -1) + '</div>';

    h += '<div class="section">' + sectionHeader('Target Selection') +
        dropdownControl('Target Mode', 'targetMode',
            d.targetMode != null ? d.targetMode : 0,
            TARGET_MODES, 'hotkeys', 'How hotkeys select their target NPC');
    if ((d.targetMode || 0) === 1) {
        h += sliderControl('Search Radius', 'nearestNPCRadius',
            d.nearestNPCRadius || 500, 100, 2000, 50,
            '{0} units', 'hotkeys', 'Radius for Nearest NPC target mode');
    } else {
        h += infoRow('Search Radius', 'N/A');
    }
    h += '</div>';

    h += '<div class="section">' + sectionHeader('Status') +
        infoRow('Hotkey System', d.hotkeyStatus || 'Unknown') +
        infoRow('Wheel Menu', d.wheelMenuStatus || 'Unknown') + '</div>';

    h += infoText('Hotkey rebinding requires MCM. Key capture in PrismaUI coming in a future update.');
    return h;
}

function renderCurrencyPage(d) {
    var h = '<div class="section">' + sectionHeader('Gold Settings') +
        toggleControl('Allow Conjured Gold', 'allowConjuredGold',
            d.allowConjuredGold, 'currency',
            'Allow NPCs to conjure gold during transactions') + '</div>';

    h += '<div class="section">' + sectionHeader('Debt Tracking') +
        infoRow('Total Debts', d.debtCount != null ? d.debtCount : 0);
    var debts = d.debts || [];
    if (debts.length === 0) {
        h += infoText('No active debts.');
    } else {
        debts.forEach(function(debt) {
            h += '<div class="card"><div class="card-header">' +
                '<span class="card-title">' + escHtml(debt.npcName) + '</span>' +
                '<span class="card-subtitle">' + debt.amount + ' gold</span>' +
                '</div></div>';
        });
    }
    h += '</div>';
    return h;
}

function renderTravelPage(d) {
    var h = '<div class="section">' + sectionHeader('Active Travel Slots') +
        infoRow('Slots in Use', d.activeSlots != null ? d.activeSlots : 0) + '</div>';

    var slots = d.slots || [];
    for (var i = 0; i < 5; i++) {
        var slot = slots[i] || {};
        h += '<div class="section">' + sectionHeader('Slot ' + (i + 1));
        if (slot.active) {
            h += infoRow('NPC', slot.npcName || 'Unknown') +
                infoRow('Destination', slot.destination || 'Unknown') +
                infoRow('Status', slot.status || 'Traveling') +
                '<div class="mt-8">' +
                actionButton('Clear Slot', 'clearTravelSlot', { slot: i },
                    'btn-danger', 'Clear travel slot ' + (i + 1) + '?') + '</div>';
        } else {
            h += infoText('Empty');
        }
        h += '</div>';
    }

    h += '<div class="section mt-12">' +
        actionButton('Reset All Travel', 'resetAllTravel', {},
            'btn-danger', 'Reset all travel slots? Active travelers will be stopped.') +
        '</div>';
    return h;
}

function renderBountyPage(d) {
    var h = '<div class="section">' + sectionHeader('Arrest Settings') +
        sliderControl('Arrest Cooldown', 'arrestCooldown',
            d.arrestCooldown != null ? d.arrestCooldown : 60,
            0, 300, 5, '{0} sec', 'bounty', 'Cooldown between arrest attempts') +
        sliderControl('Persuasion Time Limit', 'persuasionTimeLimit',
            d.persuasionTimeLimit != null ? d.persuasionTimeLimit : 90,
            30, 300, 5, '{0} sec', 'bounty', 'Time limit for persuasion during arrest') +
        '</div>';

    h += '<div class="section">' + sectionHeader('Hold Bounties');
    var bounties = d.bounties || {};
    HOLD_NAMES.forEach(function(hold) {
        var val = bounties[hold] != null ? bounties[hold] : 0;
        h += '<div class="control-row"><span class="label">' + escHtml(hold) +
            ': <span class="text-accent">' + val + ' gold</span></span>';
        if (val > 0) {
            h += actionButton('Clear', 'clearBounty', { hold: hold },
                'btn-danger', 'Clear bounty in ' + hold + '?');
        }
        h += '</div>';
    });
    h += '</div>';

    h += '<div class="section mt-12">' +
        actionButton('Clear All Bounties', 'clearAllBounties', {},
            'btn-danger', 'Clear all bounties in every hold?') + '</div>';
    return h;
}

function renderSurvivalPage(d) {
    var h = '<div class="section">' + sectionHeader('Survival System') +
        toggleControl('Enable Survival Tracking', 'survivalEnabled',
            d.survivalEnabled, 'survival',
            'Master toggle for the survival needs system') + '</div>';

    h += '<div class="section">' + sectionHeader('Hunger') +
        toggleControl('Track Hunger', 'hungerEnabled', d.hungerEnabled, 'survival') +
        sliderControl('Hunger Rate', 'hungerRate',
            d.hungerRate != null ? d.hungerRate : 1.0,
            0.25, 3.0, 0.25, '{1}x', 'survival', 'Hunger accumulation rate multiplier') +
        sliderControl('Auto-Eat Threshold', 'autoEatThreshold',
            d.autoEatThreshold != null ? d.autoEatThreshold : 50,
            0, 100, 5, '{0}%', 'survival', 'Hunger level at which NPCs eat automatically') +
        '</div>';

    h += '<div class="section">' + sectionHeader('Fatigue') +
        toggleControl('Track Fatigue', 'fatigueEnabled', d.fatigueEnabled, 'survival') +
        sliderControl('Fatigue Rate', 'fatigueRate',
            d.fatigueRate != null ? d.fatigueRate : 1.0,
            0.25, 3.0, 0.25, '{1}x', 'survival', 'Fatigue accumulation rate multiplier') +
        '</div>';

    h += '<div class="section">' + sectionHeader('Cold') +
        toggleControl('Track Cold', 'coldEnabled', d.coldEnabled, 'survival') +
        sliderControl('Cold Rate', 'coldRate',
            d.coldRate != null ? d.coldRate : 1.0,
            0.25, 3.0, 0.25, '{1}x', 'survival', 'Cold accumulation rate multiplier') +
        '</div>';

    var tracked = d.trackedFollowers || [];
    if (tracked.length > 0) {
        h += '<div class="section">' + sectionHeader('Tracked Followers');
        tracked.forEach(function(f, i) {
            h += '<div class="control-row"><span class="label">' + escHtml(f.name) +
                (f.excluded ? ' <span class="text-muted">(excluded)</span>' : '') +
                '</span>' +
                actionButton(f.excluded ? 'Include' : 'Exclude',
                    'toggleSurvivalExclude', { index: i, name: f.name },
                    'btn-secondary') + '</div>';
        });
        h += '</div>';
    }

    return h;
}

function renderFollowersPage(d) {
    var h = '<div class="section">' + sectionHeader('Framework Settings') +
        dropdownControl('Framework Mode', 'frameworkMode',
            d.frameworkMode != null ? d.frameworkMode : 0,
            FRAMEWORK_MODES, 'followers') +
        sliderControl('Max Followers', 'maxFollowers',
            d.maxFollowers != null ? d.maxFollowers : 20,
            1, 30, 1, '{0}', 'followers') +
        toggleControl('Auto-Dismiss on Hostility', 'autoDismissHostile',
            d.autoDismissHostile, 'followers') +
        toggleControl('Track Relationships', 'trackRelationships',
            d.trackRelationships, 'followers') +
        sliderControl('Rapport Decay Rate', 'rapportDecay',
            d.rapportDecay != null ? d.rapportDecay : 1.0,
            0, 5, 0.25, '{1}x', 'followers') +
        sliderControl('Leaving Threshold', 'leavingThreshold',
            d.leavingThreshold != null ? d.leavingThreshold : -60,
            -100, -10, 5, '{0}', 'followers',
            'Rapport below which followers may leave') +
        sliderControl('Relationship Cooldown', 'relCooldown',
            d.relCooldown != null ? d.relCooldown : 120,
            60, 300, 15, '{0} sec', 'followers') + '</div>';

    var companions = d.companions || [];
    if (companions.length > 0) {
        h += '<div class="section">' + sectionHeader('Companions') +
            '<div class="flex gap-8 mb-8" style="flex-wrap:wrap">';
        companions.forEach(function(c, i) {
            var active = i === State.selectedCompanionIdx;
            h += '<button class="btn ' + (active ? 'btn-accent' : '') +
                ' companion-select" data-idx="' + i + '">' +
                escHtml(c.name) + '</button>';
        });
        h += '</div>';

        var sel = companions[State.selectedCompanionIdx] || companions[0];
        if (sel) h += renderCompanionCard(sel);
        h += '</div>';
    } else {
        h += '<div class="section">' + sectionHeader('Companions') +
            infoText('No companions currently registered.') + '</div>';
    }

    h += '<div class="section">' + sectionHeader('Maintenance') +
        '<div class="flex gap-8">' +
        actionButton('Reset All Companions', 'resetAllCompanions', {},
            'btn-danger', 'Reset all companion data? This cannot be undone.') +
        '</div></div>';
    return h;
}

function renderCompanionCard(c) {
    var h = '<div class="card"><div class="card-header">' +
        '<span class="card-title">' + escHtml(c.name) + '</span>' +
        '<span class="card-subtitle">' + escHtml(c.race || '') + '</span></div>';

    var rapport = c.rapport != null ? c.rapport : 0;
    var mood = c.mood != null ? c.mood : 50;
    h += barControl('Rapport', rapport, -100, 100, rapport >= 0 ? 'positive' : 'negative') +
        barControl('Trust', c.trust != null ? c.trust : 25, 0, 100, 'neutral') +
        barControl('Loyalty', c.loyalty != null ? c.loyalty : 50, 0, 100, 'neutral') +
        barControl('Mood', mood, -100, 100, mood >= 0 ? 'positive' : 'negative');

    h += dropdownControl('Combat Style', 'companionCombatStyle',
        COMBAT_STYLES.indexOf(c.combatStyle || 'balanced'),
        COMBAT_STYLES, 'followers', null, c.name);

    h += infoRow('Home', c.home || 'None');

    h += '<div class="flex gap-8 mt-8">' +
        actionButton('Assign Home Here', 'assignHomeHere',
            { name: c.name }, 'btn-secondary') +
        actionButton('Clear Home', 'clearCompanionHome',
            { name: c.name }, 'btn-secondary',
            'Clear the custom home for ' + c.name + '?') +
        actionButton('Dismiss', 'dismissFollower',
            { name: c.name }, 'btn-danger',
            'Dismiss ' + c.name + ' from your party?') +
        '</div></div>';
    return h;
}

function renderOutfitsPage(d) {
    var npcs = d.npcs || [];
    if (npcs.length === 0) {
        return '<div class="section">' + sectionHeader('Outfit Management') +
            infoText('No NPCs with outfit data found.') + '</div>';
    }

    var h = '<div class="section">' + sectionHeader('Select NPC');
    var npcNames = npcs.map(function(n) { return n.name; });
    h += dropdownControl('NPC', 'selectedOutfitNPC',
        State.selectedOutfitNPCIdx, npcNames, 'outfits') + '</div>';

    var selNPC = npcs[State.selectedOutfitNPCIdx] || npcs[0];
    if (selNPC) {
        h += '<div class="section">' + sectionHeader(selNPC.name + ' \u2014 Outfit') +
            toggleControl('Lock Outfit', 'outfitLocked',
                selNPC.locked, 'outfits', 'Prevent this NPC from changing equipment',
                selNPC.name);

        var presets = selNPC.presets || [];
        if (presets.length > 0) {
            h += '<div class="mt-8">';
            presets.forEach(function(p, i) {
                h += '<div class="control-row"><span class="label">' + escHtml(p.name) +
                    '</span><div class="flex gap-8">' +
                    actionButton('Apply', 'applyPreset',
                        { npc: selNPC.name, preset: i }, 'btn-secondary') +
                    actionButton('Delete', 'deletePreset',
                        { npc: selNPC.name, preset: i }, 'btn-danger',
                        'Delete outfit preset "' + p.name + '"?') +
                    '</div></div>';
            });
            h += '</div>';
        } else {
            h += infoText('No outfit presets saved.');
        }
        h += '</div>';
    }
    return h;
}

// =============================================================================
// Event Binding
// =============================================================================

function bindPageControls(pageName, container) {
    // Toggle switches
    container.querySelectorAll('.setting-toggle').forEach(function(el) {
        el.addEventListener('change', function() {
            sendSettingChanged(el.dataset.page, el.dataset.key,
                String(el.checked), el.dataset.target);
        });
    });

    // Sliders — update display on drag, send on release
    container.querySelectorAll('.setting-slider').forEach(function(el) {
        var valEl = document.getElementById(el.id + '-val');
        el.addEventListener('input', function() {
            if (valEl) valEl.textContent = formatSliderValue(el.value, el.dataset.format);
        });
        el.addEventListener('change', function() {
            sendSettingChanged(el.dataset.page, el.dataset.key,
                el.value, el.dataset.target);
        });
    });

    // Dropdowns
    container.querySelectorAll('.setting-dropdown').forEach(function(el) {
        el.addEventListener('change', function() {
            sendSettingChanged(el.dataset.page, el.dataset.key,
                el.value, el.dataset.target);

            // Special: outfit NPC selector changes which NPC is shown
            if (el.dataset.key === 'selectedOutfitNPC') {
                State.selectedOutfitNPCIdx = parseInt(el.value) || 0;
                if (State.pageData.outfits) {
                    renderPage('outfits', State.pageData.outfits);
                }
            }
        });
    });

    // Action buttons
    container.querySelectorAll('[data-action]').forEach(function(el) {
        el.addEventListener('click', function() {
            var action = el.dataset.action;
            var confirmMsg = el.dataset.confirm;
            var data = {};
            for (var k in el.dataset) {
                if (k !== 'action' && k !== 'confirm') data[k] = el.dataset[k];
            }

            if (confirmMsg) {
                showConfirm(confirmMsg, function() { sendActionRequest(action, data); });
            } else {
                sendActionRequest(action, data);
            }
        });
    });

    // Companion selector buttons (Followers page)
    container.querySelectorAll('.companion-select').forEach(function(el) {
        el.addEventListener('click', function() {
            State.selectedCompanionIdx = parseInt(el.dataset.idx) || 0;
            renderPage('followers', State.pageData.followers);
        });
    });
}

// =============================================================================
// Communication (JS -> C++)
// =============================================================================

function sendSettingChanged(page, key, value, target) {
    var payload = { page: page, key: key, value: value };
    if (target) payload.target = target;
    Interop.call('settingChanged', JSON.stringify(payload));
}

function sendActionRequest(action, data) {
    var payload = { action: action };
    if (data) {
        for (var k in data) payload[k] = data[k];
    }
    Interop.call('actionRequested', JSON.stringify(payload));
}

function closeMenu() {
    Interop.call('menuClosed', '');
}

// =============================================================================
// Confirmation Dialog
// =============================================================================

function showConfirm(message, onConfirm) {
    State.pendingConfirm = onConfirm;
    document.getElementById('confirmMessage').textContent = message;
    document.getElementById('confirmDialog').classList.remove('hidden');
}

function hideConfirm() {
    document.getElementById('confirmDialog').classList.add('hidden');
    State.pendingConfirm = null;
}

document.getElementById('confirmYes').addEventListener('click', function() {
    var cb = State.pendingConfirm;
    hideConfirm();
    if (cb) cb();
});

document.getElementById('confirmNo').addEventListener('click', function() {
    hideConfirm();
});

// =============================================================================
// Notification Toast
// =============================================================================

var notifTimer = null;

function showNotificationToast(message) {
    var el = document.getElementById('notification');
    el.textContent = message;
    el.classList.remove('hidden');
    if (notifTimer) clearTimeout(notifTimer);
    notifTimer = setTimeout(function() {
        el.classList.add('hidden');
        notifTimer = null;
    }, 3000);
}

// =============================================================================
// Keyboard Handling
// =============================================================================

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (!document.getElementById('confirmDialog').classList.contains('hidden')) {
            hideConfirm();
        } else {
            closeMenu();
        }
        e.preventDefault();
    }
});

// =============================================================================
// PrismaUI Interop Registration (C++ -> JS)
// =============================================================================

Interop.register('onMenuOpened', function() {
    requestPageData(State.activePage);
});

Interop.register('receivePageData', function(jsonStr) {
    var data = safeParseJson(jsonStr);
    if (!data || !data.page) {
        console.error('receivePageData: invalid data');
        return;
    }
    renderPage(data.page, data);
});

Interop.register('showNotification', function(message) {
    showNotificationToast(message);
});

// =============================================================================
// Tab Click Handlers
// =============================================================================

document.querySelectorAll('.tab').forEach(function(tab) {
    tab.addEventListener('click', function() {
        switchTab(tab.dataset.page);
    });
});

// =============================================================================
// Init
// =============================================================================

(function() {
    console.log('SeverActions PrismaUI: app.js loaded');
})();
