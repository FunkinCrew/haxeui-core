package haxe.ui.styles;

import haxe.crypto.Sha1;
import haxe.ui.core.Component;
import haxe.ui.styles.elements.AnimationKeyFrames;
import haxe.ui.styles.elements.ImportElement;
import haxe.ui.styles.elements.MediaQuery;
import haxe.ui.styles.elements.RuleElement;

using StringTools;

class StyleSheet {
    public var name:String;

    private var _imports:Array<ImportElement> = [];
    private var _rules:Array<RuleElement> = [];

    private var _mediaQueries:Array<MediaQuery> = [];

    private var _animations:Map<String, AnimationKeyFrames> = new Map<String, AnimationKeyFrames>();
    public var animations(get, never):Map<String, AnimationKeyFrames>;
    private function get_animations():Map<String, AnimationKeyFrames> {
        return _animations;
    }

    public function new() {
    }

    public function addImport(el:ImportElement) {
        _imports.push(el);
    }

    public var imports(get, null):Array<ImportElement>;
    private function get_imports():Array<ImportElement> {
        return _imports;
    }

    public var rules(get, null):Array<RuleElement>;
    private function get_rules():Array<RuleElement> {
        var r = _rules.copy();

        for (mq in _mediaQueries) {
            if (mq.relevant) {
                r = r.concat(mq.styleSheet.rules);
            }
        }

        return r;
    }

    public var hasMediaQueries(get, null):Bool;
    private function get_hasMediaQueries():Bool {
        return _mediaQueries.length > 0;
    }

    public function findRule(selector:String, useCache = false):RuleElement {
        for (r in rules) {
            if (r.selector.toString() == selector) {
                return r;
            }
        }
        return null;
    }

    public function findMatchingRules(selector:String, useCache = false):Array<RuleElement> {
        var m = [];
        for (r in rules) {
            if (r.selector.toString() == selector) {
                m.push(r);
            }
        }
        return m;
    }

    public function removeRule(selector:String) {
        var r = findRule(selector);
        if (r != null) {
            _rules.remove(r);
            _ruleIndex = null;
        }
    }

    public function removeAllRules() {
        _rules = [];
        _ruleIndex = null;
        _parsedCss = [];
    }

    public function clear() {
        removeAllRules();
        _imports = [];
        _mediaQueries = [];
        _animations = new Map<String, AnimationKeyFrames>();
    }

    public function addRule(el:RuleElement) {
        if (el.directiveCount == 0) {
            return;
        }
        _rules.push(el);
        _ruleIndex = null;
    }

    public function addMediaQuery(el:MediaQuery) {
        _mediaQueries.push(el);
    }

    public function addAnimation(el:AnimationKeyFrames) {
        _animations.set(el.id, el);
    }

    var _parsedCss:Array<String> = [];
    public function parse(css:String) {
        if (css == null) {
            return;
        }
        if (css.trim().length == 0) {
            return;
        }
        var hash = Sha1.encode(css);
        if (_parsedCss.indexOf(hash) != -1) {
            return;
        }

        var parser = new Parser();
        var ss = parser.parse(css);
        var f = new StyleSheet();
        for (i in ss.imports) {
            var importCss = ToolkitAssets.instance.getText(i.url);
            var importStyleSheet = new Parser().parse(importCss);
            f.merge(importStyleSheet);
        }

        f.merge(ss);
        merge(f);
        _parsedCss.push(hash);
    }

    public function merge(styleSheet:StyleSheet) {
        _imports = _imports.concat(styleSheet._imports);
        _rules = _rules.concat(styleSheet._rules);
        _ruleIndex = null;
        _mediaQueries = _mediaQueries.concat(styleSheet._mediaQueries);
        for (k in styleSheet._animations.keys()) {
            _animations.set(k, styleSheet._animations.get(k));
        }
    }

    public function buildStyleFor(c:Component, style:Style = null):Style {
        if (style == null) {
            style = {};
        }
        if (_ruleIndex == null) {
            _ruleIndex = new RuleIndex(_rules);
        }
        var candidates = _ruleIndex.candidatesFor(c);
        for (i in candidates) {
            var r = _rules[i];
            if (!r.match(c)) {
                continue;
            }
            style.mergeDirectives(r.directives);
        }

        for (mq in _mediaQueries) {
            if (mq.relevant) {
                mq.styleSheet.buildStyleFor(c, style);
            }
        }

        return style;
    }

    private var _ruleIndex:RuleIndex = null;
}

@:access(haxe.ui.core.Component)
private class RuleIndex {
    private var universal:Array<Int> = [];
    private var byId:Map<String, Array<Int>> = new Map<String, Array<Int>>();
    private var byClass:Map<String, Array<Int>> = new Map<String, Array<Int>>();
    private var byNode:Map<String, Array<Int>> = new Map<String, Array<Int>>();
    private var result:Array<Int> = [];

    public function new(rules:Array<RuleElement>) {
        for (i in 0...rules.length) {
            var parts = rules[i].selector.parts;
            if (parts.length == 0) {
                universal.push(i);
                continue;
            }
            var part = parts[parts.length - 1];
            if (part.nodeName == "*") {
                universal.push(i);
            } else if (part.id != null) {
                add(byId, part.id, i);
            } else if (part.className != null) {
                add(byClass, part.classNameParts[0], i);
            } else if (part.pseudoClass != null) {
                add(byClass, ":" + part.pseudoClass, i);
            } else if (part.nodeName != null) {
                add(byNode, part.nodeName, i);
            } else {
                universal.push(i);
            }
        }
    }

    private static function add(map:Map<String, Array<Int>>, key:String, i:Int) {
        var list = map.get(key);
        if (list == null) {
            list = [];
            map.set(key, list);
        }
        list.push(i);
    }

    // The returned array is reused, so it must be read before the next call.
    public function candidatesFor(c:Component):Array<Int> {
        result.resize(0);
        for (i in universal) {
            result.push(i);
        }
        if (c.id != null) {
            append(byId.get(c.id));
        }
        append(byNode.get(c.nodeName));
        for (cls in c.classes) {
            append(byClass.get(cls));
        }
        result.sort(compareInt);
        var n = 0;
        for (i in 0...result.length) {
            if (n == 0 || result[n - 1] != result[i]) {
                result[n++] = result[i];
            }
        }
        result.resize(n);
        return result;
    }

    private inline function append(list:Array<Int>) {
        if (list != null) {
            for (i in list) {
                result.push(i);
            }
        }
    }

    private static function compareInt(a:Int, b:Int):Int {
        return a - b;
    }
}
