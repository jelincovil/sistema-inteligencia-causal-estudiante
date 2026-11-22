//! Global cross-argument support-cycle detection.
//!
//! Local derivation checks follow one argument's premises and assumption
//! edges. They cannot see mutual support between arguments, for example
//! `A1: C.b <- C.a` and `A2: C.a <- C.b`. This module builds the support
//! graph over the whole kernel — nodes are claim ids, edges are premise →
//! conclusion — and reports non-trivial strongly connected components.
//!
//! An argument is flagged only when its conclusion and at least one of its
//! premises lie in the same non-trivial component, or when it feeds its own
//! conclusion back through one argument (self edge). Alternative
//! derivations of the same conclusion that do not lie on the cycle keep
//! their own verdict.

use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};

use arg_model::LoadedArgument;

/// Argument id → sorted member claims of the support cycle it sits on.
pub(crate) fn support_cycles(arguments: &[LoadedArgument]) -> BTreeMap<String, Vec<String>> {
    let mut outgoing: BTreeMap<&str, BTreeSet<&str>> = BTreeMap::new();
    let mut incoming: BTreeMap<&str, BTreeSet<&str>> = BTreeMap::new();
    let mut nodes: BTreeSet<&str> = BTreeSet::new();
    for argument in arguments {
        nodes.insert(argument.conclusion.as_str());
        for premise in &argument.premises {
            nodes.insert(premise.as_str());
            outgoing
                .entry(premise.as_str())
                .or_default()
                .insert(argument.conclusion.as_str());
            incoming
                .entry(argument.conclusion.as_str())
                .or_default()
                .insert(premise.as_str());
        }
    }

    let self_edges: HashSet<&str> = arguments
        .iter()
        .filter(|argument| {
            argument
                .premises
                .iter()
                .any(|premise| premise == &argument.conclusion)
        })
        .map(|argument| argument.conclusion.as_str())
        .collect();

    let components = strongly_connected_components(&nodes, &outgoing, &incoming);
    let mut component_of: HashMap<&str, usize> = HashMap::new();
    for (index, component) in components.iter().enumerate() {
        let nontrivial = component.len() > 1
            || (component.len() == 1 && self_edges.contains(component[0].as_str()));
        if nontrivial {
            for member in component {
                component_of.insert(member.as_str(), index);
            }
        }
    }

    let mut flagged = BTreeMap::new();
    for argument in arguments {
        let Some(&component) = component_of.get(argument.conclusion.as_str()) else {
            continue;
        };
        if !argument
            .premises
            .iter()
            .any(|premise| component_of.get(premise.as_str()) == Some(&component))
        {
            continue;
        }
        flagged.insert(argument.id.clone(), components[component].clone());
    }
    flagged
}

fn strongly_connected_components(
    nodes: &BTreeSet<&str>,
    outgoing: &BTreeMap<&str, BTreeSet<&str>>,
    incoming: &BTreeMap<&str, BTreeSet<&str>>,
) -> Vec<Vec<String>> {
    let order = finish_order(nodes, outgoing);
    let mut visited: HashSet<&str> = HashSet::new();
    let mut components = Vec::new();
    for start in order.into_iter().rev() {
        if visited.contains(start) {
            continue;
        }
        let mut component = Vec::new();
        let mut stack = vec![start];
        while let Some(node) = stack.pop() {
            if !visited.insert(node) {
                continue;
            }
            component.push(node.to_string());
            if let Some(children) = incoming.get(node) {
                for child in children {
                    if !visited.contains(child) {
                        stack.push(*child);
                    }
                }
            }
        }
        component.sort();
        components.push(component);
    }
    components
}

fn finish_order<'a>(
    nodes: &BTreeSet<&'a str>,
    outgoing: &BTreeMap<&'a str, BTreeSet<&'a str>>,
) -> Vec<&'a str> {
    let mut visited: HashSet<&'a str> = HashSet::new();
    let mut order = Vec::with_capacity(nodes.len());
    for &start in nodes {
        if visited.contains(start) {
            continue;
        }
        // (node, expanded): expanded nodes are popped again to be recorded
        // after their children are fully explored.
        let mut stack: Vec<(&'a str, bool)> = vec![(start, false)];
        while let Some((node, expanded)) = stack.pop() {
            if expanded {
                order.push(node);
                continue;
            }
            if visited.contains(node) {
                continue;
            }
            visited.insert(node);
            stack.push((node, true));
            if let Some(children) = outgoing.get(node) {
                for child in children.iter().rev() {
                    if !visited.contains(child) {
                        stack.push((*child, false));
                    }
                }
            }
        }
    }
    order
}
