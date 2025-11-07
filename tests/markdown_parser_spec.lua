-- Load utils to extend string with split() and other methods
require "utils"

describe("Markdown Parser", function()
    local parser

    before_each(function()
        package.loaded['markdown-parser'] = nil
        parser = require "markdown-parser"
    end)

    describe("Basic bullet point hierarchy", function()
        it("parses single top-level item", function()
            local content = "* Item one"
            local result = parser.parse(content)

            assert.are.equal(1, #result.children)
            assert.are.equal("Item one", result.children[1].text)
        end)

        it("parses multiple top-level items", function()
            local content = "* Item one\n* Item two\n* Item three"
            local result = parser.parse(content)

            assert.are.equal(3, #result.children)
            assert.are.equal("Item one", result.children[1].text)
            assert.are.equal("Item two", result.children[2].text)
            assert.are.equal("Item three", result.children[3].text)
        end)

        it("parses nested items", function()
            local content = "* Parent\n  * Child one\n  * Child two"
            local result = parser.parse(content)

            assert.are.equal(1, #result.children)
            assert.are.equal("Parent", result.children[1].text)
            assert.are.equal(2, #result.children[1].children)
            assert.are.equal("Child one", result.children[1].children[1].text)
            assert.are.equal("Child two", result.children[1].children[2].text)
        end)

        it("handles both * and - bullets", function()
            local content = "- Item one\n  * Child one\n- Item two"
            local result = parser.parse(content)

            assert.are.equal(2, #result.children)
            assert.are.equal("Item one", result.children[1].text)
            assert.are.equal("Child one", result.children[1].children[1].text)
        end)
    end)

    describe("Line prefix parsing", function()
        it("parses checkbox - unchecked", function()
            local content = "* [ ] Task"
            local result = parser.parse(content)

            assert.are.equal("Task", result.children[1].text)
            assert.is_false(result.children[1].checkbox)
        end)

        it("parses checkbox - checked", function()
            local content = "* [x] Task"
            local result = parser.parse(content)

            assert.are.equal("Task", result.children[1].text)
            assert.is_true(result.children[1].checkbox)
        end)

        it("parses icon", function()
            local content = "* :fa-heart: Item"
            local result = parser.parse(content)

            assert.are.equal("Item", result.children[1].text)
            assert.are.equal("heart", result.children[1].icon)
        end)

        it("parses date", function()
            local content = "* 2025-01-15 - Item"
            local result = parser.parse(content)

            assert.are.equal("Item", result.children[1].text)
            assert.are.equal("2025-01-15", result.children[1].date)
        end)

        it("parses all prefixes in order", function()
            local content = "* [ ] :fa-star: 2025-12-25 - Holiday task"
            local result = parser.parse(content)

            assert.are.equal("Holiday task", result.children[1].text)
            assert.is_false(result.children[1].checkbox)
            assert.are.equal("star", result.children[1].icon)
            assert.are.equal("2025-12-25", result.children[1].date)
        end)

        it("handles no prefixes", function()
            local content = "* Plain item"
            local result = parser.parse(content)

            assert.are.equal("Plain item", result.children[1].text)
            assert.is_nil(result.children[1].checkbox)
            assert.is_nil(result.children[1].icon)
            assert.is_nil(result.children[1].date)
        end)
    end)

    describe("Bracket expansion", function()
        it("expands simple bracket list", function()
            local content = "* Test (One, Two, Three)"
            local result = parser.parse(content)

            assert.are.equal("Test", result.children[1].text)
            assert.are.equal(3, #result.children[1].children)
            assert.are.equal("One", result.children[1].children[1].text)
            assert.are.equal("Two", result.children[1].children[2].text)
            assert.are.equal("Three", result.children[1].children[3].text)
        end)

        it("expands bracket with semicolon groups as attributes", function()
            local content = "* Test (One: A, B; Two: C)"
            local result = parser.parse(content)

            assert.are.equal("Test", result.children[1].text)
            assert.is_nil(result.children[1].children)
            assert.is_not_nil(result.children[1].attributes)

            -- First attribute "One: A, B"
            assert.is_not_nil(result.children[1].attributes.one)
            assert.are.equal(1, #result.children[1].attributes.one)
            local one_attr = result.children[1].attributes.one[1]
            assert.is_nil(one_attr.name)
            assert.are.equal(2, #one_attr.children)
            assert.are.equal("A", one_attr.children[1].text)
            assert.are.equal("B", one_attr.children[2].text)

            -- Second attribute "Two: C"
            assert.is_not_nil(result.children[1].attributes.two)
            assert.are.equal(1, #result.children[1].attributes.two)
            local two_attr = result.children[1].attributes.two[1]
            assert.is_nil(two_attr.name)
            assert.are.equal(1, #two_attr.children)
            assert.are.equal("C", two_attr.children[1].text)
        end)

        it("handles bracket expansion with existing children", function()
            local content = "* Test (A, B)\n  * C"
            local result = parser.parse(content)

            assert.are.equal("Test", result.children[1].text)
            assert.are.equal(3, #result.children[1].children)
            assert.are.equal("A", result.children[1].children[1].text)
            assert.are.equal("B", result.children[1].children[2].text)
            assert.are.equal("C", result.children[1].children[3].text)
        end)
    end)

    describe("Colon expansion", function()
        it("expands colon list", function()
            local content = "* Test: One, Two, Three"
            local result = parser.parse(content)

            assert.is_not_nil(result.attributes.test)
            assert.are.equal(1, #result.attributes.test)
            local test_attr = result.attributes.test[1]
            assert.is_nil(test_attr.name)
            assert.are.equal(3, #test_attr.children)
            assert.are.equal("One", test_attr.children[1].text)
            assert.are.equal("Two", test_attr.children[2].text)
            assert.are.equal("Three", test_attr.children[3].text)
            assert.is_true(not result.children or #result.children == 0)
        end)

        it("combines bracket and colon as top-level attribute", function()
            local content = "* Test (One, Two): A, B"
            local result = parser.parse(content)

            -- This creates a top-level attribute with keyword "Test", name "One, Two"
            assert.is_not_nil(result.attributes.test)
            assert.are.equal(1, #result.attributes.test)

            local attr = result.attributes.test[1]
            assert.are.equal("One, Two", attr.name)
            assert.are.equal(2, #attr.children)
            assert.are.equal("A", attr.children[1].text)
            assert.are.equal("B", attr.children[2].text)

            -- No children items
            assert.is_true(not result.children or #result.children == 0)
        end)

        it("expands bracket with multiple named attributes", function()
            local content = "* Task (Option (One): A, B; Option (Two): C)"
            local result = parser.parse(content)

            assert.are.equal("Task", result.children[1].text)
            assert.is_not_nil(result.children[1].attributes)
            assert.is_not_nil(result.children[1].attributes.option)
            assert.are.equal(2, #result.children[1].attributes.option)

            local first = result.children[1].attributes.option[1]
            assert.are.equal("One", first.name)
            assert.are.equal(2, #first.children)
            assert.are.equal("A", first.children[1].text)
            assert.are.equal("B", first.children[2].text)

            local second = result.children[1].attributes.option[2]
            assert.are.equal("Two", second.name)
            assert.are.equal(1, #second.children)
            assert.are.equal("C", second.children[1].text)
        end)
    end)

    describe("Attributes", function()
        it("parses simple attribute", function()
            local content = "* Item\n  * Options: A, B, C"
            local result = parser.parse(content)

            assert.are.equal("Item", result.children[1].text)
            assert.is_not_nil(result.children[1].attributes)
            assert.is_not_nil(result.children[1].attributes.options)
            assert.are.equal(1, #result.children[1].attributes.options)

            local attr_entry = result.children[1].attributes.options[1]
            assert.is_nil(attr_entry.name)
            assert.are.equal(3, #attr_entry.children)
            assert.are.equal("A", attr_entry.children[1].text)
            assert.are.equal("B", attr_entry.children[2].text)
            assert.are.equal("C", attr_entry.children[3].text)
        end)

        it("parses attribute with custom name in brackets", function()
            local content = "* Item\n  * Options (Symptoms): Fever, Cough"
            local result = parser.parse(content)

            assert.is_not_nil(result.children[1].attributes)
            assert.is_not_nil(result.children[1].attributes.options)
            assert.are.equal(1, #result.children[1].attributes.options)

            local attr_entry = result.children[1].attributes.options[1]
            assert.are.equal("Symptoms", attr_entry.name)
            assert.are.equal(2, #attr_entry.children)
            assert.are.equal("Fever", attr_entry.children[1].text)
            assert.are.equal("Cough", attr_entry.children[2].text)
        end)

        it("separates attributes from children", function()
            local content = "* Item\n  * Options: A, B\n  * Regular child"
            local result = parser.parse(content)

            assert.are.equal(1, #result.children[1].children)
            assert.are.equal("Regular child", result.children[1].children[1].text)

            assert.are.equal(1, #result.children[1].attributes.options)
            assert.are.equal(2, #result.children[1].attributes.options[1].children)
        end)

        it("allows multiple attributes with same keyword", function()
            local content = "* Item\n  * Tag: urgent\n  * Tag: important"
            local result = parser.parse(content)

            assert.are.equal(2, #result.children[1].attributes.tag)
            assert.are.equal(1, #result.children[1].attributes.tag[1].children)
            assert.are.equal("urgent", result.children[1].attributes.tag[1].children[1].text)
            assert.are.equal(1, #result.children[1].attributes.tag[2].children)
            assert.are.equal("important", result.children[1].attributes.tag[2].children[1].text)
        end)

        it("allows multiple attributes with same keyword but different names", function()
            local content = "* Item\n  * Option (One): A, B\n  * Option (Two): C"
            local result = parser.parse(content)

            assert.are.equal(2, #result.children[1].attributes.option)

            local first_attr = result.children[1].attributes.option[1]
            assert.are.equal("One", first_attr.name)
            assert.are.equal(2, #first_attr.children)
            assert.are.equal("A", first_attr.children[1].text)
            assert.are.equal("B", first_attr.children[2].text)

            local second_attr = result.children[1].attributes.option[2]
            assert.are.equal("Two", second_attr.name)
            assert.are.equal(1, #second_attr.children)
            assert.are.equal("C", second_attr.children[1].text)
        end)

        it("treats attribute keywords as case-insensitive", function()
            local content = "* Item\n  * Tag: one\n  * TAG: two\n  * TaG: three"
            local result = parser.parse(content)

            -- All three should be stored under lowercase "tag"
            assert.is_not_nil(result.children[1].attributes.tag)
            assert.are.equal(3, #result.children[1].attributes.tag)
            assert.are.equal("one", result.children[1].attributes.tag[1].children[1].text)
            assert.are.equal("two", result.children[1].attributes.tag[2].children[1].text)
            assert.are.equal("three", result.children[1].attributes.tag[3].children[1].text)
        end)
    end)

    describe("All: attribute inheritance", function()
        it("applies All: to all siblings", function()
            local content = [[* All:
  * Common child
* One
* Two]]
            local result = parser.parse(content)

            assert.are.equal(2, #result.children)
            assert.are.equal("One", result.children[1].text)
            assert.are.equal("Two", result.children[2].text)

            assert.are.equal(1, #result.children[1].children)
            assert.are.equal("Common child", result.children[1].children[1].text)

            assert.are.equal(1, #result.children[2].children)
            assert.are.equal("Common child", result.children[2].children[1].text)
        end)

        it("applies All: attributes to siblings", function()
            local content = [[* All:
  * Options: A, B, C
* One
* Two]]
            local result = parser.parse(content)

            assert.are.equal(2, #result.children)

            assert.are.equal(1, #result.children[1].attributes.options)
            assert.are.equal(3, #result.children[1].attributes.options[1].children)

            assert.are.equal(1, #result.children[2].attributes.options)
            assert.are.equal(3, #result.children[2].attributes.options[1].children)
        end)

        it("orders All: children correctly relative to explicit children", function()
            local content = [[* One
  * A
* All:
  * B
  * C
* Two
  * D]]
            local result = parser.parse(content)

            -- One appears BEFORE All:, so gets: A (explicit), then B, C (appended from All)
            assert.are.equal(3, #result.children[1].children)
            assert.are.equal("A", result.children[1].children[1].text)
            assert.are.equal("B", result.children[1].children[2].text)
            assert.are.equal("C", result.children[1].children[3].text)

            -- Two appears AFTER All:, so gets: B, C (prepended from All), then D (explicit)
            assert.are.equal(3, #result.children[2].children)
            assert.are.equal("B", result.children[2].children[1].text)
            assert.are.equal("C", result.children[2].children[2].text)
            assert.are.equal("D", result.children[2].children[3].text)
        end)

        it("handles multiple All: at same level", function()
            local content = [[* One
  * A
* All:
  * B
  * C
* Two
  * D
* All:
  * E]]
            local result = parser.parse(content)

            -- One gets: A, B, C, E
            assert.are.equal(4, #result.children[1].children)
            assert.are.equal("A", result.children[1].children[1].text)
            assert.are.equal("B", result.children[1].children[2].text)
            assert.are.equal("C", result.children[1].children[3].text)
            assert.are.equal("E", result.children[1].children[4].text)

            -- Two gets: B, C, D, E
            assert.are.equal(4, #result.children[2].children)
            assert.are.equal("B", result.children[2].children[1].text)
            assert.are.equal("C", result.children[2].children[2].text)
            assert.are.equal("D", result.children[2].children[3].text)
            assert.are.equal("E", result.children[2].children[4].text)
        end)

        it("does not include All: items in final output", function()
            local content = [[* All:
  * Common
* One
* Two]]
            local result = parser.parse(content)

            assert.are.equal(2, #result.children)
            assert.are.equal("One", result.children[1].text)
            assert.are.equal("Two", result.children[2].text)
        end)
    end)

    describe("Complex scenarios", function()
        it("handles deeply nested structures with all features", function()
            local content = [[* [ ] :fa-heart: 2025-01-15 - Project (Phase 1, Phase 2)
  * All:
    * Status: active
  * Task one
    * Subtask
  * Task two]]
            local result = parser.parse(content)

            assert.are.equal(1, #result.children)
            local project = result.children[1]

            assert.are.equal("Project", project.text)
            assert.is_false(project.checkbox)
            assert.are.equal("heart", project.icon)
            assert.are.equal("2025-01-15", project.date)

            -- Children: Phase 1, Phase 2, Task one, Task two
            assert.are.equal(4, #project.children)

            local phase_1 = project.children[1]
            assert.are.equal("Phase 1", phase_1.text)
            assert.are.equal(1, #phase_1.attributes.status)
            assert.are.equal(1, #phase_1.attributes.status[1].children)
            assert.are.equal("active", phase_1.attributes.status[1].children[1].text)

            local phase_2 = project.children[2]
            assert.are.equal("Phase 2", phase_2.text)
            assert.are.equal(1, #phase_2.attributes.status)
            assert.are.equal(1, #phase_2.attributes.status[1].children)
            assert.are.equal("active", phase_2.attributes.status[1].children[1].text)

            local task_one = project.children[3]
            assert.are.equal("Task one", task_one.text)
            assert.are.equal(1, #task_one.attributes.status)
            assert.are.equal(1, #task_one.attributes.status[1].children)
            assert.are.equal("active", task_one.attributes.status[1].children[1].text)
            assert.are.equal(1, #task_one.children)
            assert.are.equal("Subtask", task_one.children[1].text)

            local task_two = project.children[4]
            assert.are.equal("Task two", task_two.text)
            assert.are.equal(1, #task_two.attributes.status)
            assert.are.equal(1, #task_two.attributes.status[1].children)
            assert.are.equal("active", task_two.attributes.status[1].children[1].text)
        end)
    end)

    describe("File manager compatibility", function()
        it("has version property", function()
            assert.is_not_nil(parser.version)
            assert.are.equal("number", type(parser.version))
        end)

        it("has parse function", function()
            assert.is_not_nil(parser.parse)
            assert.are.equal("function", type(parser.parse))
        end)
    end)
end)
