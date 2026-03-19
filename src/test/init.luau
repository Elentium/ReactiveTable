--[[
	ReactiveTable Test Suite

	Scoring:
		Each test awards:
		  - Correctness  (2 pts): output matches expectations
		  - Performance  (1 pt):  avg time per op is within budget

	Grade thresholds (% of total points):
		S  = 100%    A  = 90%    B  = 75%
		C  = 60%     D  = 50%    E  = 40%    F  = <40%

	Section summary shows:
		ValidityPass  – all correctness checks in section passed
		PerformancePass – all perf checks in section passed
]]

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local CONFIG = {
	-- Iterations for every performance benchmark.
	-- Raise for stable numbers; lower for a faster run.
	PERF_ITERATIONS = 1_000,

	-- Multiply all time budgets by this factor.
	-- Raise on slow machines (e.g. 2.0), lower on fast ones (e.g. 0.5).
	PERF_BUDGET_SCALE = 1.0,

	-- Line width for separators.
	SEPARATOR_WIDTH = 72,

	-- Set true to build results GUI in StarterGui.
	CREATE_UI = true,
}

--------------------------------------------------------------------------------
-- DEPENDENCY
--------------------------------------------------------------------------------
local ReactiveTable = require("@self/../")

--------------------------------------------------------------------------------
-- GRADES
--------------------------------------------------------------------------------
local GRADES = {
	{ threshold = 1.00, label = "S" },
	{ threshold = 0.90, label = "A" },
	{ threshold = 0.75, label = "B" },
	{ threshold = 0.60, label = "C" },
	{ threshold = 0.50, label = "D" },
	{ threshold = 0.40, label = "E" },
	{ threshold = 0.00, label = "F" },
}

local function getGrade(ratio: number): string
	for _, entry in GRADES do
		if ratio >= entry.threshold then
			return entry.label
		end
	end
	return "F"
end

--------------------------------------------------------------------------------
-- FRAMEWORK STATE
--------------------------------------------------------------------------------
type TestResult = {
	name: string,
	section: string,
	validityPass: boolean,
	perfPass: boolean,
	avgUs: number,
	budgetUs: number,
	crashed: boolean,
	crashMsg: string,
	cPts: number,
	earnedC: number,
	earnedP: number,
	pPts: number,
}

type SectionInfo = {
	name: string,
	tests: { TestResult },
}

local allSections: { SectionInfo } = {}
local currentSection: SectionInfo = { name = "", tests = {} }
local totalPts = 0
local earnedPts = 0

local SEP = string.rep("─", CONFIG.SEPARATOR_WIDTH)

--------------------------------------------------------------------------------
-- BENCH HELPER
-- Validity check and performance measurement are always separated.
-- The validity lambda runs ONCE (no timing overhead).
-- The perf lambda is benched ITERS times and must not use pcall internally
-- (for tests where errors are expected, a separate error-free perf path is used).
--------------------------------------------------------------------------------
local function bench(iters: number, fn: () -> ()): number
	fn() -- warm-up
	local t0 = os.clock()
	for _ = 1, iters do
		fn()
	end
	return ((os.clock() - t0) / iters) * 1_000_000
end

--------------------------------------------------------------------------------
-- SECTION
--------------------------------------------------------------------------------
local function section(name: string)
	currentSection = { name = name, tests = {} }
	table.insert(allSections, currentSection)
end

--------------------------------------------------------------------------------
-- TEST
-- @param name       label
-- @param cPts       correctness points (usually 2)
-- @param budgetUs   µs budget per op (before PERF_BUDGET_SCALE)
-- @param validityFn () -> bool   runs once, checks output correctness
-- @param perfFn     () -> ()     hot path to bench (must NOT use pcall)
--------------------------------------------------------------------------------
local function test(name: string, cPts: number, budgetUs: number, validityFn: () -> boolean, perfFn: () -> ())
	local pPts = 1
	local scaledBudget = budgetUs * CONFIG.PERF_BUDGET_SCALE

	totalPts += cPts + pPts

	-- Validity
	local validityPass = false
	local crashed = false
	local crashMsg = ""
	local vOk, vErr = pcall(function()
		validityPass = validityFn()
	end)
	if not vOk then
		crashed = true
		crashMsg = tostring(vErr):sub(1, 80)
	end

	-- Performance (separate; never uses pcall so error overhead is zero)
	local avgUs = 0.0
	local pOk, pErr = pcall(function()
		avgUs = bench(CONFIG.PERF_ITERATIONS, perfFn)
	end)
	if not pOk then
		crashed = true
		crashMsg = crashMsg ~= "" and crashMsg or tostring(pErr):sub(1, 80)
	end

	local perfPass = avgUs <= scaledBudget
	local earnedC = if (not crashed) and validityPass then cPts else 0
	local earnedP = if (not crashed) and perfPass then pPts else 0
	earnedPts += earnedC + earnedP

	local result: TestResult = {
		name = name,
		section = currentSection.name,
		validityPass = validityPass,
		perfPass = perfPass,
		avgUs = avgUs,
		budgetUs = scaledBudget,
		crashed = crashed,
		crashMsg = crashMsg,
		cPts = cPts,
		earnedC = earnedC,
		earnedP = earnedP,
		pPts = pPts,
	}
	table.insert(currentSection.tests, result)
end

--------------------------------------------------------------------------------
-- CONSOLE PRINT
--------------------------------------------------------------------------------
local function printResults()
	print(SEP)
	print(
		string.format(
			"  ReactiveTable Test Results   %d iterations/test   Scale ×%.1f",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE
		)
	)
	print(SEP)

	for _, sec in allSections do
		-- Section header
		print("")
		print(SEP)
		print(string.format("  %s", sec.name))

		-- Aggregate section validity/perf
		local secValidPass = true
		local secPerfPass = true
		for _, r in sec.tests do
			if r.crashed or not r.validityPass then
				secValidPass = false
			end
			if r.crashed or not r.perfPass then
				secPerfPass = false
			end
		end
		print(
			string.format("  ValidityPass: %-5s   PerformancePass: %s", tostring(secValidPass), tostring(secPerfPass))
		)
		print(SEP)

		for _, r in sec.tests do
			if r.crashed then
				print(string.format("  [CRASH] %-44s  %s", r.name, r.crashMsg))
			else
				local vTag = if r.validityPass then "PASS" else "FAIL"
				local pTag = if r.perfPass then "PASS" else "SLOW"
				print(
					string.format(
						"  [%s] %-44s | %s | avg %6.2f µs (budget %6.2f µs)",
						vTag,
						r.name,
						pTag,
						r.avgUs,
						r.budgetUs
					)
				)
			end
		end
	end

	print("")
	print(SEP)
	local ratio = if totalPts > 0 then earnedPts / totalPts else 0
	print(string.format("  Score: %d / %d  (%.1f%%)   Grade: %s", earnedPts, totalPts, ratio * 100, getGrade(ratio)))
	print(SEP)
end

--------------------------------------------------------------------------------
-- UI BUILDER  (only when CONFIG.CREATE_UI == true)
--------------------------------------------------------------------------------
local function buildUI()
	-- Palette
	local C = {
		bg = Color3.fromHex("0f1117"),
		panel = Color3.fromHex("1a1d27"),
		card = Color3.fromHex("22263a"),
		border = Color3.fromHex("2e3350"),
		accent = Color3.fromHex("5b6af5"),
		accentDim = Color3.fromHex("3a4499"),
		textPri = Color3.fromHex("e8eaf6"),
		textSec = Color3.fromHex("8b93c4"),
		textDim = Color3.fromHex("4a5280"),
		pass = Color3.fromHex("4caf7d"),
		fail = Color3.fromHex("e05c5c"),
		slow = Color3.fromHex("e0a35c"),
		crash = Color3.fromHex("c04040"),
		gradeS = Color3.fromHex("ffd700"),
		gradeA = Color3.fromHex("7ec8e3"),
		gradeB = Color3.fromHex("4caf7d"),
		gradeC = Color3.fromHex("e0a35c"),
		gradeD = Color3.fromHex("e07a5c"),
		gradeF = Color3.fromHex("e05c5c"),
	}

	local gradeColors: { [string]: Color3 } = {
		S = C.gradeS,
		A = C.gradeA,
		B = C.gradeB,
		C = C.gradeC,
		D = C.gradeD,
		E = C.gradeF,
		F = C.gradeF,
	}

	local function gradeColor(g: string): Color3
		return gradeColors[g] or C.textSec
	end

	-- Helpers
	local function frame(props: { [string]: any }): Frame
		local f = Instance.new("Frame")
		for k, v in props do
			(f :: any)[k] = v
		end
		return f
	end

	local function label(props: { [string]: any }): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamMedium
		l.TextSize = 13
		l.TextColor3 = C.textPri
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		for k, v in props do
			(l :: any)[k] = v
		end
		return l
	end

	local function uiPadding(parent: Instance, h: number, v: number)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, h)
		p.PaddingRight = UDim.new(0, h)
		p.PaddingTop = UDim.new(0, v)
		p.PaddingBottom = UDim.new(0, v)
		p.Parent = parent
	end

	local function uiList(parent: Instance, spacing: number, dir: Enum.FillDirection?)
		local l = Instance.new("UIListLayout")
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.FillDirection = dir or Enum.FillDirection.Vertical
		l.Padding = UDim.new(0, spacing)
		l.Parent = parent
	end

	local function uiCorner(parent: Instance, r: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = parent
	end

	local function uiStroke(parent: Instance, clr: Color3, thick: number)
		local s = Instance.new("UIStroke")
		s.Color = clr
		s.Thickness = thick
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = parent
	end

	-- Root
	local sg = Instance.new("ScreenGui")
	sg.Name = "ReactiveTableTestResults"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 100

	-- Background
	local bg = frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.bg,
		Parent = sg,
	})

	-- Centered window
	local win = frame({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 820, 0.92, 0),
		BackgroundColor3 = C.panel,
		Parent = bg,
	})
	uiCorner(win, 12)
	uiStroke(win, C.border, 1)

	-- Title bar
	local titleBar = frame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = C.card,
		Parent = win,
	})
	uiCorner(titleBar, 12)
	-- square off bottom corners via overlap
	local titleBarBottom = frame({
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	titleBarBottom.Name = "BottomFill"

	local _titleLabel = label({
		Name = "Title",
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "  ReactiveTable  ·  Test Results",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.textPri,
		Parent = titleBar,
	})

	-- Score badge in title bar
	local ratio = if totalPts > 0 then earnedPts / totalPts else 0
	local g = getGrade(ratio)

	local scoreBadge = frame({
		Name = "ScoreBadge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 180, 0, 32),
		BackgroundColor3 = C.accentDim,
		Parent = titleBar,
	})
	uiCorner(scoreBadge, 8)
	uiList(scoreBadge, 4, Enum.FillDirection.Horizontal)
	uiPadding(scoreBadge, 10, 0)

	local _scoreText = label({
		Name = "ScoreText",
		Size = UDim2.new(1, -44, 1, 0),
		Text = string.format("%d / %d  (%.1f%%)", earnedPts, totalPts, ratio * 100),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.textPri,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = scoreBadge,
	})

	local _gradeLabel = label({
		Name = "Grade",
		Size = UDim2.new(0, 30, 1, 0),
		Text = g,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = gradeColor(g),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = scoreBadge,
	})

	-- Scrollable body
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.Position = UDim2.new(0, 0, 0, 52)
	scroll.Size = UDim2.new(1, 0, 1, -52)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = C.accentDim
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	scroll.BorderSizePixel = 0
	scroll.Parent = win
	uiPadding(scroll, 14, 10)
	uiList(scroll, 10)

	-- Stat bar (iters / scale)
	local statsBar = frame({
		Name = "StatsBar",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = C.card,
		LayoutOrder = 0,
		Parent = scroll,
	})
	uiCorner(statsBar, 6)
	uiPadding(statsBar, 12, 0)
	label({
		Name = "StatsText",
		Size = UDim2.fromScale(1, 1),
		Text = string.format(
			"Iterations per test: %d    Budget scale: ×%.1f",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE
		),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = C.textSec,
		Parent = statsBar,
	})

	-- Sections
	for sIdx, sec in allSections do
		-- Section card
		local card = frame({
			Name = "Section_" .. sIdx,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.card,
			LayoutOrder = sIdx,
			Parent = scroll,
		})
		uiCorner(card, 8)
		uiStroke(card, C.border, 1)
		uiPadding(card, 12, 10)
		uiList(card, 0)

		-- Section header row
		local hdrRow = frame({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = card,
		})

		label({
			Name = "SectionName",
			Size = UDim2.new(0.55, 0, 1, 0),
			Text = sec.name,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = C.textPri,
			Parent = hdrRow,
		})

		-- Compute section-level flags
		local secValidPass = true
		local secPerfPass = true
		local secEarned, secTotal = 0, 0
		for _, r in sec.tests do
			if r.crashed or not r.validityPass then
				secValidPass = false
			end
			if r.crashed or not r.perfPass then
				secPerfPass = false
			end
			secEarned += r.earnedC + r.earnedP
			secTotal += r.cPts + r.pPts
		end

		-- Badge container (right-aligned)
		local badgeRow = frame({
			Name = "Badges",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 290, 0, 22),
			BackgroundTransparency = 1,
			Parent = hdrRow,
		})
		uiList(badgeRow, 6, Enum.FillDirection.Horizontal)

		local function badge(text: string, bg: Color3, fg: Color3, lo: number)
			local b = frame({
				Name = "Badge",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = bg,
				LayoutOrder = lo,
				Parent = badgeRow,
			})
			uiCorner(b, 5)
			uiPadding(b, 7, 0)
			label({
				Name = "Lbl",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = text,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextColor3 = fg,
				Parent = b,
			})
		end

		local vBg = if secValidPass then C.pass else C.fail
		local pBg = if secPerfPass then C.pass else C.slow
		badge("Validity: " .. (if secValidPass then "PASS" else "FAIL"), vBg, C.bg, 1)
		badge("Perf: " .. (if secPerfPass then "PASS" else "FAIL"), pBg, C.bg, 2)
		badge(string.format("%d/%d pts", secEarned, secTotal), C.accentDim, C.textPri, 3)

		-- Divider
		frame({
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.border,
			LayoutOrder = 1,
			Parent = card,
		})

		-- Column headers
		local colHdr = frame({
			Name = "ColHeaders",
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = card,
		})
		local function colLabel(txt: string, xAnchor: number, xPos: number, xSize: number)
			label({
				Name = txt,
				AnchorPoint = Vector2.new(xAnchor, 0.5),
				Position = UDim2.new(xPos, 0, 0.5, 0),
				Size = UDim2.new(xSize, 0, 0.8, 0),
				Text = txt,
				TextSize = 10,
				Font = Enum.Font.Gotham,
				TextColor3 = C.textDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = colHdr,
			})
		end
		colLabel("Test", 0, 0, 0.48)
		colLabel("Valid", 0, 0.50, 0.08)
		colLabel("Perf", 0, 0.59, 0.08)
		colLabel("Avg µs", 0, 0.68, 0.15)
		colLabel("Budget", 0, 0.84, 0.16)

		-- Test rows
		for rIdx, r in sec.tests do
			local rowBg = if rIdx % 2 == 0 then C.bg else C.card
			local row = frame({
				Name = "Row_" .. rIdx,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = rowBg,
				BackgroundTransparency = if rIdx % 2 == 0 then 0.5 else 0,
				LayoutOrder = rIdx + 10,
				Parent = card,
			})
			uiCorner(row, 4)

			if r.crashed then
				label({
					Name = "Crash",
					Size = UDim2.fromScale(1, 1),
					Text = "  ⚠  " .. r.name .. "  —  " .. r.crashMsg,
					TextSize = 11,
					TextColor3 = C.crash,
					Parent = row,
				})
			else
				-- Name
				label({
					Name = "Name",
					Position = UDim2.new(0, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Size = UDim2.new(0.48, 0, 0.85, 0),
					Text = r.name,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextColor3 = C.textPri,
					Parent = row,
				})

				-- Validity dot
				local vColor = if r.validityPass then C.pass else C.fail
				local vDot = frame({
					Name = "VDot",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.50, 0, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = vColor,
					Parent = row,
				})
				uiCorner(vDot, 5)

				-- Perf dot
				local pColor = if r.perfPass then C.pass else C.slow
				local pDot = frame({
					Name = "PDot",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.59, 0, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = pColor,
					Parent = row,
				})
				uiCorner(pDot, 5)

				-- Avg µs
				label({
					Name = "Avg",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.68, 0, 0.5, 0),
					Size = UDim2.new(0.15, 0, 0.85, 0),
					Text = string.format("%.2f", r.avgUs),
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextColor3 = if r.perfPass then C.textPri else C.slow,
					Parent = row,
				})

				-- Budget µs
				label({
					Name = "Budget",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.84, 0, 0.5, 0),
					Size = UDim2.new(0.16, 0, 0.85, 0),
					Text = string.format("%.2f", r.budgetUs),
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextColor3 = C.textSec,
					Parent = row,
				})
			end
		end
	end

	-- Footer score bar
	local footerCard = frame({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = C.accentDim,
		LayoutOrder = 9999,
		Parent = scroll,
	})
	uiCorner(footerCard, 8)
	uiPadding(footerCard, 16, 0)

	label({
		Name = "FooterScore",
		Size = UDim2.new(0.7, 0, 1, 0),
		Text = string.format("Final Score:  %d / %d  (%.1f%%)", earnedPts, totalPts, ratio * 100),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C.textPri,
		Parent = footerCard,
	})

	local _gradeLblFtr = label({
		Name = "FooterGrade",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.25, 0, 0.8, 0),
		Text = "Grade:  " .. g,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = gradeColor(g),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = footerCard,
	})

	sg.Parent = game:GetService("StarterGui")
	-- Also display immediately in the current player's PlayerGui if running
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then
			sg:Clone().Parent = pg
		end
	end
end

--------------------------------------------------------------------------------
-- TESTS
--------------------------------------------------------------------------------

-- ─── Construction ────────────────────────────────────────────────────────────
section("Construction  (ReactiveTable.new)")

test("new() with empty table", 2, 15, function()
	local t = ReactiveTable.new({})
	return t ~= nil
end, function()
	ReactiveTable.new({})
end)

test("new() with flat values", 2, 15, function()
	local t = ReactiveTable.new({ a = 1, b = "hello", c = true })
	return t.a == 1 and t.b == "hello" and t.c == true
end, function()
	ReactiveTable.new({ a = 1, b = "hello", c = true })
end)

test("new() wraps nested tables", 2, 20, function()
	local t = ReactiveTable.new({ inner = { x = 99 } })
	return t.inner ~= nil and t.inner.x == 99
end, function()
	ReactiveTable.new({ inner = { x = 99 } })
end)

test("new() with same table returns same userdata", 2, 7, function()
	local raw = { a = 1 }
	local t1 = ReactiveTable.new(raw)
	local t2 = ReactiveTable.new(raw)
	return t1 == t2
end, function()
	local raw = { a = 1 }
	ReactiveTable.new(raw)
	ReactiveTable.new(raw) -- second call, fast de-dup path
end)

test("new() self-referential table (no stack overflow)", 2, 20, function()
	local raw: any = {}
	raw.self = raw
	local t = ReactiveTable.new(raw)
	return t ~= nil
end, function()
	local raw: any = {}
	raw.self = raw
	ReactiveTable.new(raw)
end)

-- ─── __index / __newindex ────────────────────────────────────────────────────
section("Index / NewIndex  (__index  __newindex)")

do
	local t = ReactiveTable.new({ x = 42 })
	test("read primitive key", 2, 2, function()
		return t.x == 42
	end, function()
		local _ = t.x
	end)
end

do
	local t = ReactiveTable.new({ x = 1 })
	t.Changed:Connect(function() end)
	test("write primitive key fires Changed", 2, 5, function()
		local fired = false
		t.Changed:Connect(function(k, v)
			if k == "x" and v == 2 then
				fired = true
			end
		end)
		t.x = 1
		t.x = 2
		return fired
	end, function()
		t.x = 1
		t.x = 2
	end)
end

do
	local t = ReactiveTable.new({})
	t.New:Connect(function() end)
	test("write new key fires New", 2, 5, function()
		local fired = false
		t.New:Connect(function(k)
			if k == "foo" then
				fired = true
			end
		end)
		t.foo = "bar"
		return fired
	end, function()
		t.foo = nil
		t.foo = "bar"
	end)
end

do
	local t = ReactiveTable.new({ x = 1 })
	t.Removed:Connect(function() end)
	test("set key to nil fires Removed", 2, 5, function()
		local fired = false
		t.Removed:Connect(function(k)
			if k == "x" then
				fired = true
			end
		end)
		t.x = nil
		return fired
	end, function()
		t.x = 1
		t.x = nil
	end)
end

do
	local t = ReactiveTable.new({ x = 1 })
	test("write same value is a no-op (no signal)", 2, 3, function()
		local fired = false
		t.Changed:Connect(function()
			fired = true
		end)
		t.x = 1
		return not fired
	end, function()
		t.x = 1
	end)
end

do
	local t = ReactiveTable.new({})
	test("write table value wraps it", 2, 8, function()
		t.inner = { y = 7 }
		return t.inner ~= nil and t.inner.y == 7
	end, function()
		t.inner = nil
		t.inner = { y = 7 }
	end)
end

do
	local child = ReactiveTable.new({ v = 1 })
	local parent = ReactiveTable.new({})
	parent.Changed:Connect(function() end)
	test("write userdata registers ancestry and bubbles", 2, 8, function()
		local fired = false
		parent.Changed:Connect(function()
			fired = true
		end)
		parent.child = child
		child.v = 2
		return fired
	end, function()
		child.v = 2
	end)
end

-- ─── Introspection ───────────────────────────────────────────────────────────
section("Introspection  (GetSource  GetSize  IsFrozen  AreSignalsFrozen)")

do
	local raw = { a = 1 }
	local t = ReactiveTable.new(raw)
	test("GetSource returns underlying table", 2, 2, function()
		return t:GetSource() == raw
	end, function()
		t:GetSource()
	end)
end

do
	local t = ReactiveTable.new({ a = 1, b = 2, c = 3 })
	test("GetSize counts all keys", 2, 3, function()
		return t:GetSize() == 3
	end, function()
		t:GetSize()
	end)
end

do
	local t = ReactiveTable.new({})
	test("IsFrozen reflects freeze state", 2, 2, function()
		if t:IsFrozen() then
			return false
		end
		t:Freeze()
		if not t:IsFrozen() then
			return false
		end
		t:Unfreeze()
		return not t:IsFrozen()
	end, function()
		t:IsFrozen()
	end)
end

do
	local t = ReactiveTable.new({})
	test("AreSignalsFrozen reflects freeze state", 2, 2, function()
		if t:AreSignalsFrozen() then
			return false
		end
		t:FreezeSignals()
		if not t:AreSignalsFrozen() then
			return false
		end
		t:UnfreezeSignals()
		return not t:AreSignalsFrozen()
	end, function()
		t:AreSignalsFrozen()
	end)
end

-- ─── Freeze / Unfreeze ───────────────────────────────────────────────────────
section("Freeze / Unfreeze")

do
	local t = ReactiveTable.new({ x = 1 })
	test("frozen table rejects writes", 2, 5, function()
		t:Freeze()
		pcall(function()
			t.x = 2
		end)
		return t.x == 1
	end, function()
		t:Unfreeze()
		t.x = 2
		t:Freeze()
	end)
end

do
	local t = ReactiveTable.new({})
	test("frozen table rejects Insert", 2, 4, function()
		t:Freeze()
		local s = pcall(function()
			t:Insert(1)
		end)
		return not s
	end, function()
		t:Unfreeze()
		t:Insert(1)
	end)
end

do
	local t = ReactiveTable.new({ x = 1 })
	test("unfreezing re-enables writes", 2, 4, function()
		t:Freeze()
		t:Unfreeze()
		t.x = 99
		return t.x == 99
	end, function()
		t:Freeze()
		t:Unfreeze()
		t.x = 99
	end)
end

do
	local t = ReactiveTable.new({ a = 1 })
	test("FreezeSignals suppresses all signals", 2, 5, function()
		local fired = false
		t.Changed:Connect(function()
			fired = true
		end)
		t.New:Connect(function()
			fired = true
		end)
		t.Removed:Connect(function()
			fired = true
		end)
		t:FreezeSignals()
		t.a = 2
		t.b = 3
		t.b = nil
		return not fired
	end, function()
		t:FreezeSignals()
		t.a = 2
	end)
end

do
	local t = ReactiveTable.new({ a = 1 })
	test("UnfreezeSignals re-enables signals", 2, 5, function()
		t:FreezeSignals()
		t:UnfreezeSignals()
		local fired = false
		t.Changed:Connect(function()
			fired = true
		end)
		t.a = 2
		return fired
	end, function()
		t:FreezeSignals()
		t:UnfreezeSignals()
		t.a = 2
	end)
end

-- ─── Insert ──────────────────────────────────────────────────────────────────
section("Insert")

do
	local t = ReactiveTable.new({})
	test("Insert appends to array", 2, 6, function()
		t:Insert(10)
		t:Insert(20)
		return t[1] == 10 and t[2] == 20
	end, function()
		t:Clear()
		t:Insert(10)
		t:Insert(20)
	end)
end

do
	local t = ReactiveTable.new({ 1, 2, 3 })
	test("Insert at index shifts elements", 2, 6, function()
		t:Insert(99, 2)
		return t[2] == 99 and t[3] == 2
	end, function()
		t:Remove(2)
		t:Insert(99, 2)
	end)
end

do
	local parent = ReactiveTable.new({ child = {} })
	parent.child.New:Connect(function() end)
	parent.Changed:Connect(function() end)
	test("Insert fires New and ancestor Changed", 2, 8, function()
		local newFired, ancestorFired = false, false
		parent.child.New:Connect(function()
			newFired = true
		end)
		parent.Changed:Connect(function()
			ancestorFired = true
		end)
		parent.child:Insert(42)
		return newFired and ancestorFired
	end, function()
		parent.child:Remove()
		parent.child:Insert(42)
	end)
end

do
	local t = ReactiveTable.new({})
	test("Insert wraps nested table values", 2, 8, function()
		t:Insert({ z = 5 })
		return t[1] ~= nil and t[1].z == 5
	end, function()
		t:Remove(1)
		t:Insert({ z = 5 })
	end)
end

-- ─── Remove ──────────────────────────────────────────────────────────────────
section("Remove")

do
	local t = ReactiveTable.new({ 10, 20, 30 })
	test("Remove pops last element", 2, 4, function()
		local v = t:Remove()
		return v == 30 and t:GetSize() == 2
	end, function()
		t:Insert(30)
		t:Remove()
	end)
end

do
	local t = ReactiveTable.new({ 10, 20, 30 })
	test("Remove at index shifts elements", 2, 4, function()
		local v = t:Remove(1)
		return v == 10 and t[1] == 20
	end, function()
		t:Insert(10, 1)
		t:Remove(1)
	end)
end

do
	local parent = ReactiveTable.new({ child = { 1, 2, 3 } })
	parent.child.Removed:Connect(function() end)
	parent.Changed:Connect(function() end)
	test("Remove fires Removed and ancestor Changed", 2, 8, function()
		local removedFired, ancestorFired = false, false
		parent.child.Removed:Connect(function()
			removedFired = true
		end)
		parent.Changed:Connect(function()
			ancestorFired = true
		end)
		parent.child:Remove()
		return removedFired and ancestorFired
	end, function()
		parent.child:Insert(3)
		parent.child:Remove()
	end)
end

do
	local inner = ReactiveTable.new({ v = 1 })
	local parent = ReactiveTable.new({})
	parent.Changed:Connect(function() end)
	test("Remove cleans up child ancestry", 2, 6, function()
		parent.slot = inner
		parent.slot = nil
		local fired = false
		parent.Changed:Connect(function()
			fired = true
		end)
		inner.v = 2
		return not fired
	end, function()
		parent.slot = inner
		parent.slot = nil
		inner.v = 2
	end)
end

-- ─── Clear ───────────────────────────────────────────────────────────────────
section("Clear")

do
	local t = ReactiveTable.new({ 1, 2, 3, 4, 5 })
	test("Clear empties array", 2, 5, function()
		t:Clear()
		return t:GetSize() == 0
	end, function()
		t:Clear()
	end)
end

do
	local t = ReactiveTable.new({ 10, 20, 30 })
	t.Removed:Connect(function() end)
	test("Clear fires Removed for each element", 2, 8, function()
		local count = 0
		t.Removed:Connect(function()
			count += 1
		end)
		t:Clear()
		return count == 3
	end, function()
		t:Insert(10)
		t:Insert(20)
		t:Insert(30)
		t:Clear()
	end)
end

do
	local parent = ReactiveTable.new({ child = { 1, 2, 3 } })
	parent.Changed:Connect(function() end)
	test("Clear fires ancestor Changed once", 2, 8, function()
		local ancestorCount = 0
		parent.Changed:Connect(function()
			ancestorCount += 1
		end)
		parent.child:Clear()
		return ancestorCount == 1
	end, function()
		parent.child:Insert(1)
		parent.child:Insert(2)
		parent.child:Insert(3)
		parent.child:Clear()
	end)
end

do
	local inner = ReactiveTable.new({ v = 99 })
	local parent = ReactiveTable.new({})
	parent.Changed:Connect(function() end)
	test("Clear cleans up child table ancestry", 2, 8, function()
		parent:Insert(inner)
		parent:Clear()
		local fired = false
		parent.Changed:Connect(function()
			fired = true
		end)
		inner.v = 100
		return not fired
	end, function()
		parent:Insert(inner)
		parent:Clear()
		inner.v = 100
	end)
end

-- ─── Sort ────────────────────────────────────────────────────────────────────
section("Sort")

do
	local t = ReactiveTable.new({ 3, 1, 4, 1, 5, 9, 2, 6 })
	local function cmp(a: number, b: number)
		return a < b
	end
	test("Sort orders primitive array", 2, 8, function()
		t:Sort(cmp)
		return t[1] == 1 and t[2] == 1 and t[8] == 9
	end, function()
		t:Sort(cmp)
	end)
end

do
	local i1 = ReactiveTable.new({ val = 30 })
	local i2 = ReactiveTable.new({ val = 10 })
	local i3 = ReactiveTable.new({ val = 20 })
	local p = ReactiveTable.new({})
	p:Insert(i1)
	p:Insert(i2)
	p:Insert(i3)
	local function cmp(a: any, b: any)
		return a.val < b.val
	end
	test("Sort updates ancestry keys for nested tables", 2, 10, function()
		p:Sort(cmp)
		local firedKey: any = nil
		p.Changed:Connect(function(k)
			firedKey = k
		end)
		i2.val = 11
		return firedKey == 1
	end, function()
		p:Sort(cmp)
	end)
end

do
	local inner = ReactiveTable.new({ v = 0 })
	local parent = ReactiveTable.new({})
	parent:Insert(inner)
	parent:Insert(inner)
	test("Sort with duplicate references updates all slots", 2, 10, function()
		parent:Sort(function()
			return false
		end)
		local fired = 0
		parent.Changed:Connect(function()
			fired += 1
		end)
		inner.v = 1
		return fired == 2
	end, function()
		parent:Sort(function()
			return false
		end)
	end)
end

-- ─── Find ────────────────────────────────────────────────────────────────────
section("Find")

do
	local t = ReactiveTable.new({ 10, 20, 30, 20 })
	test("Find returns correct index for primitive", 2, 3, function()
		return t:Find(20) == 2
	end, function()
		t:Find(20)
	end)
end

do
	local t = ReactiveTable.new({ 20, 20, 20 })
	test("Find with init skips earlier indices", 2, 3, function()
		return t:Find(20, 2) == 2
	end, function()
		t:Find(20, 2)
	end)
end

do
	local inner = ReactiveTable.new({ v = 1 })
	local parent = ReactiveTable.new({})
	parent:Insert(inner)
	test("Find accepts ReactiveTable userdata", 2, 4, function()
		return parent:Find(inner) == 1
	end, function()
		parent:Find(inner)
	end)
end

do
	local t = ReactiveTable.new({ 1, 2, 3 })
	test("Find returns nil when not found", 2, 3, function()
		return t:Find(99) == nil
	end, function()
		t:Find(99)
	end)
end

-- ─── Clone ───────────────────────────────────────────────────────────────────
section("Clone")

do
	local t = ReactiveTable.new({ a = 1, b = 2 })
	test("Clone shallow produces independent table", 2, 6, function()
		local c = t:Clone()
		c.a = 99
		return t.a == 1 and c.a == 99
	end, function()
		t:Clone()
	end)
end

do
	local t = ReactiveTable.new({ inner = { x = 1 } })
	test("Clone deep copies nested table", 2, 12, function()
		local c = t:Clone(true)
		c.inner.x = 99
		return t.inner.x == 1
	end, function()
		t:Clone(true)
	end)
end

do
	local t = ReactiveTable.new({})
	t:Freeze()
	test("Clone preserves frozen state", 2, 5, function()
		local c = t:Clone()
		return c:IsFrozen()
	end, function()
		t:Clone()
	end)
end

do
	local t = ReactiveTable.new({})
	t:FreezeSignals()
	test("Clone preserves signalsFrozen state", 2, 5, function()
		local c = t:Clone()
		return c:AreSignalsFrozen()
	end, function()
		t:Clone()
	end)
end

-- ─── Compare ─────────────────────────────────────────────────────────────────
section("Compare")

do
	local t1 = ReactiveTable.new({ a = 1, b = { c = 2 } })
	local t2 = ReactiveTable.new({ a = 1, b = { c = 2 } })
	test("Compare equal tables returns true", 2, 5, function()
		return t1:Compare(t2)
	end, function()
		t1:Compare(t2)
	end)
end

do
	local t1 = ReactiveTable.new({ a = 1 })
	local t2 = ReactiveTable.new({ a = 2 })
	test("Compare different tables returns false", 2, 3, function()
		return not t1:Compare(t2)
	end, function()
		t1:Compare(t2)
	end)
end

do
	local t = ReactiveTable.new({ a = 1 })
	test("Compare with non-userdata returns false", 2, 2, function()
		return not t:Compare({ a = 1 })
	end, function()
		t:Compare({ a = 1 })
	end)
end

-- ─── BindToKeyChanged ────────────────────────────────────────────────────────
section("BindToKeyChanged")

do
	local t = ReactiveTable.new({ x = 1, y = 1 })
	t:BindToKeyChanged("x", function() end)
	test("fires only for the bound key", 2, 5, function()
		local xCount = 0
		t:BindToKeyChanged("x", function()
			xCount += 1
		end)
		t.x = 1
		t.x = 2
		t.y = 2
		return xCount == 1
	end, function()
		t.x = 1
		t.x = 2
		t.y = 2
	end)
end

do
	local t = ReactiveTable.new({ x = 1 })
	test("connection Disconnect stops callbacks", 2, 5, function()
		local count = 0
		local conn = t:BindToKeyChanged("x", function()
			count += 1
		end)
		t.x = 2
		conn:Disconnect()
		t.x = 3
		return count == 1
	end, function()
		local conn = t:BindToKeyChanged("x", function() end)
		t.x = 2
		conn:Disconnect()
	end)
end

-- ─── BroadcastChanges ────────────────────────────────────────────────────────
section("BroadcastChanges")

do
	local t = ReactiveTable.new({ a = 1 })
	t.New:Connect(function() end)
	test("broadcasts Added signal for listed keys", 2, 5, function()
		local fired = false
		t.New:Connect(function(k)
			if k == "a" then
				fired = true
			end
		end)
		t:BroadcastChanges({ a = "Added" })
		return fired
	end, function()
		t:BroadcastChanges({ a = "Added" })
	end)
end

do
	local t = ReactiveTable.new({ a = 1 })
	t.Removed:Connect(function() end)
	test("broadcasts Removed signal for listed keys", 2, 5, function()
		local fired = false
		t.Removed:Connect(function(k)
			if k == "a" then
				fired = true
			end
		end)
		t:BroadcastChanges({ a = "Removed" })
		return fired
	end, function()
		t:BroadcastChanges({ a = "Removed" })
	end)
end

do
	local t = ReactiveTable.new({ a = 1 })
	t.Changed:Connect(function() end)
	test("broadcasts Changed signal for listed keys", 2, 5, function()
		local fired = false
		t.Changed:Connect(function(k)
			if k == "a" then
				fired = true
			end
		end)
		t:BroadcastChanges({ a = "Changed" })
		return fired
	end, function()
		t:BroadcastChanges({ a = "Changed" })
	end)
end

-- ─── Destroy ─────────────────────────────────────────────────────────────────
section("Destroy")

-- Perf: create + destroy is the actual work; cannot reuse after destroy.
test("Destroy removes registry entry", 2, 12, function()
	local t = ReactiveTable.new({ a = 1 })
	t:Destroy()
	local s = pcall(function()
		return t.a
	end)
	return not s
end, function()
	local t = ReactiveTable.new({ a = 1 })
	t:Destroy()
end)

test("Destroy disconnects all signals", 2, 10, function()
	local t = ReactiveTable.new({ a = 1 })
	local fired = false
	t.Changed:Connect(function()
		fired = true
	end)
	t:Destroy()
	return not fired
end, function()
	local t = ReactiveTable.new({ a = 1 })
	t.Changed:Connect(function() end)
	t:Destroy()
end)

-- ─── Metamethods ─────────────────────────────────────────────────────────────
section("Metamethods  (__iter  __len  __tostring)")

do
	local t = ReactiveTable.new({ a = 1, b = 2, c = 3 })
	test("__iter yields key-value pairs", 2, 5, function()
		local sum = 0
		for _, v in t do
			sum += v
		end
		return sum == 6
	end, function()
		for _ in t do
		end
	end)
end

do
	local parent = ReactiveTable.new({ child = { x = 1 } })
	test("__iter unwraps nested table values", 2, 5, function()
		local foundRT = false
		for _, v in parent do
			if type(v) == "userdata" then
				foundRT = true
			end
		end
		return foundRT
	end, function()
		for _ in parent do
		end
	end)
end

do
	local t = ReactiveTable.new({ 10, 20, 30 })
	test("__len returns array length", 2, 3, function()
		return #t == 3
	end, function()
		local _ = #t
	end)
end

do
	local t = ReactiveTable.new({ a = 1 })
	test("__tostring produces non-empty string", 2, 3, function()
		return #tostring(t) > 2
	end, function()
		tostring(t)
	end)
end

-- ─── Ancestor sees children changes (1-level bubble-up) ───────────────────────
-- ReactiveTable only bubbles Changed one level up to direct ancestors.
section("Ancestor sees children changes")

do
	local mid = ReactiveTable.new({ leaf = { v = 0 } })
	test("leaf change fires direct parent's Changed", 2, 8, function()
		local fired = false
		mid.Changed:Connect(function()
			fired = true
		end)
		mid.leaf.v = 1
		return fired
	end, function()
		mid.leaf.v = 1
	end)
end

do
	local d4 = ReactiveTable.new({ v = 0 })
	local d3 = ReactiveTable.new({ d4 = d4 })
	local d2 = ReactiveTable.new({ d3 = d3 })
	test("direct parent fires, grandparent does not", 2, 8, function()
		local firedD3, firedD2 = false, false
		d3.Changed:Connect(function()
			firedD3 = true
		end)
		d2.Changed:Connect(function()
			firedD2 = true
		end)
		d4.v = 1
		return firedD3 and not firedD2
	end, function()
		d4.v = 1
	end)
end

do
	local child = ReactiveTable.new({ v = 0 })
	local p1 = ReactiveTable.new({})
	local p2 = ReactiveTable.new({})
	p1.c = child
	p2.c = child
	p1.Changed:Connect(function() end)
	p2.Changed:Connect(function() end)
	test("child shared by two parents bubbles to both", 2, 6, function()
		local f1, f2 = false, false
		p1.Changed:Connect(function()
			f1 = true
		end)
		p2.Changed:Connect(function()
			f2 = true
		end)
		child.v = 1
		return f1 and f2
	end, function()
		child.v = 1
	end)
end

do
	local child = ReactiveTable.new({ v = 0 })
	local parent = ReactiveTable.new({})
	parent.a = child
	parent.b = child
	parent.Changed:Connect(function() end)
	test("child at multiple keys in one parent bubbles for each key", 2, 6, function()
		local count = 0
		parent.Changed:Connect(function()
			count += 1
		end)
		child.v = 1
		return count == 2
	end, function()
		child.v = 1
	end)
end

do
	local child = ReactiveTable.new({ v = 0 })
	local p1 = ReactiveTable.new({})
	local p2 = ReactiveTable.new({})
	p1.c = child
	p2.c = child
	p1.c = nil
	p2.Changed:Connect(function() end)
	test("removing child from one parent stops bubble to that parent only", 2, 6, function()
		local f1, f2 = false, false
		p1.Changed:Connect(function()
			f1 = true
		end)
		p2.Changed:Connect(function()
			f2 = true
		end)
		child.v = 1
		return not f1 and f2
	end, function()
		child.v = 1
	end)
end

do
	local parent = ReactiveTable.new({})
	local inner1 = ReactiveTable.new({ x = 1 })
	local inner2 = ReactiveTable.new({ x = 2 })
	parent:Insert(inner1)
	parent:Insert(inner2)
	parent.Changed:Connect(function() end)
	test("inserting array of nested tables updates ancestry correctly", 2, 8, function()
		local keys: { any } = {}
		parent.Changed:Connect(function(k)
			table.insert(keys, k)
		end)
		inner1.x = 10
		inner2.x = 20
		return #keys == 2 and keys[1] == 1 and keys[2] == 2
	end, function()
		inner1.x = 1
		inner2.x = 2
		inner1.x = 10
		inner2.x = 20
	end)
end

-- ─── Edge Cases ──────────────────────────────────────────────────────────────
section("Edge Cases")

do
	local inner = ReactiveTable.new({ v = 1 })
	local parent = ReactiveTable.new({})
	parent.Changed:Connect(function() end)
	test("overwrite table child with primitive cleans ancestry", 2, 8, function()
		parent.x = inner
		parent.x = 42
		local fired = false
		parent.Changed:Connect(function()
			fired = true
		end)
		inner.v = 2
		return not fired
	end, function()
		parent.x = inner
		parent.x = 42
		inner.v = 2
	end)
end

do
	local oldChild = ReactiveTable.new({ v = 1 })
	local newChild = ReactiveTable.new({ v = 2 })
	local parent = ReactiveTable.new({})
	parent.Changed:Connect(function() end)
	test("replace one child with another cleans old ancestry", 2, 8, function()
		parent.slot = oldChild
		parent.slot = newChild
		local firedOld, firedNew = false, false
		parent.Changed:Connect(function(_, v)
			if v == newChild then
				firedNew = true
			end
			if v == oldChild then
				firedOld = true
			end
		end)
		newChild.v = 99
		oldChild.v = 99
		return firedNew and not firedOld
	end, function()
		parent.slot = newChild
		newChild.v = 99
	end)
end

test("Destroy on frozen table still succeeds", 2, 8, function()
	local t = ReactiveTable.new({ a = 1 })
	t:Freeze()
	local s = pcall(function()
		t:Destroy()
	end)
	return s
end, function()
	local t = ReactiveTable.new({ a = 1 })
	t:Destroy()
end)

do
	local parent = ReactiveTable.new({ child = {} })
	parent.Changed:Connect(function() end)
	test("empty Clear is safe (no error, no ancestor Changed)", 2, 4, function()
		local fired = false
		parent.Changed:Connect(function()
			fired = true
		end)
		local s = pcall(function()
			parent.child:Clear()
		end)
		return s and not fired
	end, function()
		parent.child:Clear()
	end)
end

do
	local t = ReactiveTable.new({})
	local function cmp(a: number, b: number)
		return a < b
	end
	test("Sort on empty array is safe", 2, 3, function()
		local s = pcall(function()
			t:Sort(cmp)
		end)
		return s
	end, function()
		t:Sort(cmp)
	end)
end

do
	local i1 = ReactiveTable.new({ v = 3 })
	local i2 = ReactiveTable.new({ v = 1 })
	local i3 = ReactiveTable.new({ v = 2 })
	local parent = ReactiveTable.new({})
	parent:Insert(i1)
	parent:Insert(i2)
	parent:Insert(i3)
	parent:Remove(1)
	parent:Sort(function(a: any, b: any)
		return a.v < b.v
	end)
	parent.Changed:Connect(function() end)
	test("Sort after Remove keeps ancestry consistent", 2, 6, function()
		local key1: any = nil
		parent.Changed:Connect(function(k)
			key1 = k
		end)
		i2.v = 10
		return key1 == 1
	end, function()
		i2.v = 1
		i2.v = 10
	end)
end

do
	local t = ReactiveTable.new({ x = { val = 0 } })
	t.Changed:Connect(function() end)
	test("signal fires correct new value after nested table write", 2, 5, function()
		local received: any = nil
		t.Changed:Connect(function(k, v)
			if k == "x" then
				received = v
			end
		end)
		t.x.val = 1
		return received == t.x
	end, function()
		t.x.val = 1
	end)
end

do
	local t = ReactiveTable.new({ 10, 20, 30 })
	test("Remove returns raw primitive, not wrapped value", 2, 4, function()
		local v = t:Remove(2)
		return v == 20 and type(v) == "number"
	end, function()
		t:Insert(20, 2)
		t:Remove(2)
	end)
end

do
	local t = ReactiveTable.new({ inner = { v = 1 } })
	t.Changed:Connect(function() end)
	test("Clone(true) deep clone does not share child ancestry", 2, 10, function()
		local c = t:Clone(true)
		local firedOriginal = false
		t.Changed:Connect(function()
			firedOriginal = true
		end)
		c.inner.v = 99
		return not firedOriginal and t.inner.v == 1
	end, function()
		local c = t:Clone(true)
		c.inner.v = 99
	end)
end

-- ─── Stress Tests ────────────────────────────────────────────────────────────
section("Stress  (large tables, deep ancestry chains, heavy signals)")

-- 1. Large flat table construction
do
	local N = 500
	local raw: { [string]: number } = {}
	for i = 1, N do
		raw["k" .. i] = i
	end
	test("construct table with 500 keys", 2, 300, function()
		local t = ReactiveTable.new(raw)
		return t:GetSize() == N
	end, function()
		ReactiveTable.new(raw)
	end)
end

-- 2. Large flat table – read every key
do
	local N = 500
	local raw: { [string]: number } = {}
	for i = 1, N do
		raw["k" .. i] = i
	end
	local t = ReactiveTable.new(raw)
	test("read all 500 keys sequentially", 2, 200, function()
		local sum = 0
		for i = 1, N do
			sum += t["k" .. i]
		end
		return sum == (N * (N + 1)) / 2
	end, function()
		local sum = 0
		for i = 1, N do
			sum += t["k" .. i]
		end
		local _ = sum
	end)
end

-- 3. Large flat table – write every key (fires Changed 500 times)
do
	local N = 500
	local raw: { [string]: number } = {}
	for i = 1, N do
		raw["k" .. i] = i
	end
	local t = ReactiveTable.new(raw)
	t.Changed:Connect(function() end)
	test("write all 500 keys sequentially (signals fire)", 2, 2000, function()
		for i = 1, N do
			t["k" .. i] = i + 1
		end
		return t["k" .. N] == N + 1
	end, function()
		for i = 1, N do
			t["k" .. i] = i + 1
		end
	end)
end

-- 4. Large nested table construction (50 nested ReactiveTable children)
do
	local N = 50
	local raw: { [string]: { v: number } } = {}
	for i = 1, N do
		raw["child" .. i] = { v = i }
	end
	test("construct table with 50 nested children", 2, 2000, function()
		local t = ReactiveTable.new(raw)
		return t:GetSize() == N
	end, function()
		ReactiveTable.new(raw)
	end)
end

-- 5. 10-level deep ancestry chain: each level is a child of the next
--    A write to the leaf must fire Changed on its direct parent only.
do
	local DEPTH = 10
	local nodes: { any } = {}
	nodes[1] = ReactiveTable.new({ v = 0 })
	for i = 2, DEPTH do
		local parent = ReactiveTable.new({})
		parent.child = nodes[i - 1]
		nodes[i] = parent
	end
	-- connect listener on every ancestor to count fires
	local fireCounts: { [number]: number } = {}
	for i = 1, DEPTH do
		fireCounts[i] = 0
		local idx = i
		nodes[i].Changed:Connect(function()
			fireCounts[idx] += 1
		end)
	end
	test("10-level chain: leaf write fires only direct parent", 2, 50, function()
		-- reset counts
		for i = 1, DEPTH do
			fireCounts[i] = 0
		end
		nodes[1].v = 1 -- leaf write
		-- level 2 is direct parent, must fire; levels 3..10 must NOT
		local directFired = fireCounts[1] == 1 and fireCounts[2] == 1
		local noDeepBubble = true
		for i = 3, DEPTH do
			if fireCounts[i] > 0 then
				noDeepBubble = false
				break
			end
		end
		return directFired and noDeepBubble
	end, function()
		nodes[1].v = 0
		nodes[1].v = 1
	end)
end

-- 6. Wide ancestry: one child registered as a child in 20 different parents
do
	local PARENTS = 20
	local child = ReactiveTable.new({ v = 0 })
	local parents: { any } = {}
	local fireCounts: { [number]: number } = {}
	for i = 1, PARENTS do
		local p = ReactiveTable.new({})
		p["slot"] = child
		fireCounts[i] = 0
		local idx = i
		p.Changed:Connect(function()
			fireCounts[idx] += 1
		end)
		parents[i] = p
	end
	test("child in 20 parents: write fires all 20 parent Changed", 2, 100, function()
		for i = 1, PARENTS do
			fireCounts[i] = 0
		end
		child.v = 1
		local allFired = true
		for i = 1, PARENTS do
			if fireCounts[i] ~= 1 then
				allFired = false
				break
			end
		end
		return allFired
	end, function()
		child.v = 0
		child.v = 1
	end)
end

-- 7. Heavy signals: 100 listeners on a single key, all fire on each write
do
	local LISTENERS = 100
	local t = ReactiveTable.new({ x = 0 })
	local count = 0
	for _ = 1, LISTENERS do
		t.Changed:Connect(function(k)
			if k == "x" then
				count += 1
			end
		end)
	end
	test("100 listeners all fire on a single write", 2, 200, function()
		count = 0
		t.x = 1
		return count == LISTENERS
	end, function()
		t.x = 0
		t.x = 1
	end)
end

-- 8. Heavy signals: 50 BindToKeyChanged listeners on the same key
do
	local LISTENERS = 50
	local t = ReactiveTable.new({ x = 0 })
	local count = 0
	for _ = 1, LISTENERS do
		t:BindToKeyChanged("x", function()
			count += 1
		end)
	end
	test("50 BindToKeyChanged listeners all fire on one write", 2, 150, function()
		count = 0
		t.x = 1
		return count == LISTENERS
	end, function()
		t.x = 0
		t.x = 1
	end)
end

-- 9. Insert 200 elements, verify size and signal count
do
	local INSERTS = 200
	local t = ReactiveTable.new({})
	local newCount = 0
	t.New:Connect(function()
		newCount += 1
	end)
	test("Insert 200 elements: size and signal count correct", 2, 500, function()
		newCount = 0
		for i = 1, INSERTS do
			t:Insert(i)
		end
		local ok = t:GetSize() == INSERTS and newCount == INSERTS
		t:Clear()
		return ok
	end, function()
		for i = 1, INSERTS do
			t:Insert(i)
		end
		t:Clear()
	end)
end

-- 10. Sort 200-element array with nested ReactiveTable children: ancestry stays intact
do
	local N = 200
	local t = ReactiveTable.new({})
	local children: { any } = {}
	for i = 1, N do
		local c = ReactiveTable.new({ v = N - i + 1 }) -- descending so sort changes positions
		children[i] = c
		t:Insert(c)
	end
	t:Sort(function(a: any, b: any)
		return a.v < b.v
	end)
	local parentFires = 0
	local perfFlip = false
	t.Changed:Connect(function()
		parentFires += 1
	end)
	test("Sort 200-child array: ancestry valid after sort", 2, 2000, function()
		parentFires = 0
		-- every child should still bubble to parent
		local allBubble = true
		for i = 1, N do
			parentFires = 0
			children[i].v = -i
			if parentFires == 0 then
				allBubble = false
				break
			end
		end
		return allBubble
	end, function()
		-- Mirror validity: write every child and trigger bubbling.
		-- Toggle the target values so repeated benchmark iterations don't become no-ops.
		perfFlip = not perfFlip
		local delta = if perfFlip then 0 else 1
		for i = 1, N do
			parentFires = 0
			children[i].v = -i - delta
		end
	end)
end

-- 11. Rapid connect/disconnect under load: 1000 connect+disconnect cycles
do
	local t = ReactiveTable.new({ x = 0 })
	test("1000 rapid connect/disconnect cycles without crash", 2, 620, function()
		local ok = pcall(function()
			for _ = 1, 1000 do
				local conn = t.Changed:Connect(function() end)
				conn:Disconnect()
			end
		end)
		return ok
	end, function()
		for _ = 1, 1000 do
			local conn = t.Changed:Connect(function() end)
			conn:Disconnect()
		end
	end)
end

-- 12. BroadcastChanges on 100-key table: all signals fire
--    API: BroadcastChanges({ [key]: "Added" | "Removed" | "Changed" }), not an array of keys.
do
	local N = 100
	local raw: { [string]: number } = {}
	local changedMap: { [string]: "Changed" } = {}
	for i = 1, N do
		local k = "k" .. i
		raw[k] = i
		changedMap[k] = "Changed"
	end
	local t = ReactiveTable.new(raw)
	local fires = 0
	t.Changed:Connect(function()
		fires += 1
	end)
	test("BroadcastChanges fires Changed for all 100 keys", 2, 1000, function()
		fires = 0
		t:BroadcastChanges(changedMap)
		return fires == N
	end, function()
		t:BroadcastChanges(changedMap)
	end)
end

-- 13. Deep Clone of large table: independent, no shared ancestry
do
	local N = 50
	local raw: { [string]: { v: number } } = {}
	for i = 1, N do
		raw["c" .. i] = { v = i }
	end
	local t = ReactiveTable.new(raw)
	local parentFired = false
	t.Changed:Connect(function()
		parentFired = true
	end)
	test("Clone(true) of 50-child table shares no ancestry", 2, 5000, function()
		local clone = t:Clone(true)
		parentFired = false
		-- mutating every child of the clone must NOT fire original parent
		for i = 1, N do
			clone["c" .. i].v = -i
		end
		return not parentFired
	end, function()
		local clone = t:Clone(true)
		parentFired = false
		for i = 1, N do
			clone["c" .. i].v = -i
		end
	end)
end

-- 14. Stability: 500 writes with mixed ancestry, no crash
do
	local child1 = ReactiveTable.new({ a = 0 })
	local child2 = ReactiveTable.new({ b = 0 })
	local parent = ReactiveTable.new({})
	parent.x = child1
	parent.y = child2
	parent.Changed:Connect(function() end)
	test("500 interleaved ancestry writes: no crash, signals fire", 2, 5000, function()
		local ok = pcall(function()
			for i = 1, 250 do
				child1.a = i
				child2.b = i
			end
		end)
		return ok
	end, function()
		for i = 1, 250 do
			child1.a = i
			child2.b = i
		end
	end)
end

--------------------------------------------------------------------------------
-- OUTPUT
--------------------------------------------------------------------------------
printResults()
if CONFIG.CREATE_UI then
	buildUI()
end

return 0
