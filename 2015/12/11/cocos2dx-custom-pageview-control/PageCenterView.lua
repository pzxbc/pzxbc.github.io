-- PageCenterView.lua --

local TableUtils = require('TableUtils')

local PageCenterView = class('PageCenterView')

PageCenterView.EventType = {
	TURNING = 1,
}

PageCenterView.TouchDirection = {
	LEFT  = 1,
	RIGHT = 2,
	UP    = 3,
	DOWN  = 4,
}

PageCenterView.Direction = {
	HORIZONTAL = 1,
	VERTICAL   = 2,
}

PageCenterView.AutoScrollDirection = {
	UP = 1,
	DOWN = 2,
}

function PageCenterView:ctor(name)
	self.debugName = name

	self:_init()
end

function PageCenterView:_init()
	self._pages = {}

	self._isAutoScrolling = false
	self._autoScrollDistance = 0
	self._autoScrollSpeed = 0

	self._curPageIdx = -1
	self._doLayoutDirty = false

	self._leftBoundaryChild = nil
	self._rightBoundaryChild = nil
	self._leftBoundary = 0
	self._rightBoundary = 0
	self._pageNumShowed = 1

	self._direction = PageCenterView.Direction.VERTICAL
	self._autoScrollDirection = PageCenterView.AutoScrollDirection.DOWN
	self._touchMoveDirection = PageCenterView.TouchDirection.DOWN

	self._eventCallback = nil

	self.layout = ccui.Layout:create()
	self.layout:setClippingEnabled(true)

	local update = function (dt)
		self:update(dt)
	end
	self.layout:scheduleUpdateWithPriorityLua(update, 0)

	self:_initAction()
end

function PageCenterView:_onEnter()
	print('PageCenterView:_onEnter')
end

function PageCenterView:_initAction()
	local onNodeEvent = function (event)
		if event == 'enter' then
			self:_onEnter()
		end
	end
	self.layout:registerScriptHandler(onNodeEvent)

	self:_initTouchListener()
end

function PageCenterView:_initTouchListener()
	local onTouchBegan = function (touch, event)
		return self:onTouchBegan(touch, event)
	end
	local onTouchMoved = function (touch, event)
		return self:onTouchMoved(touch, event)
	end
	local onTouchEnded = function (touch, event)
		return self:onTouchEnded(touch, event)
	end
	local onTouchCancelled = function (touch, event)
		return self:onTouchCancelled(touch, event)
	end
	local listener = cc.EventListenerTouchOneByOne:create()
	listener:setSwallowTouches(true)

	listener:registerScriptHandler(onTouchBegan, cc.Handler.EVENT_TOUCH_BEGAN)
	listener:registerScriptHandler(onTouchMoved, cc.Handler.EVENT_TOUCH_MOVED)
	listener:registerScriptHandler(onTouchEnded, cc.Handler.EVENT_TOUCH_ENDED)
	listener:registerScriptHandler(onTouchCancelled, cc.Handler.EVENT_TOUCH_CANCELLED)

	local eventDispatcher = self.layout:getEventDispatcher()
	print('eventDispatcher', eventDispatcher, self.layout)
	eventDispatcher:addEventListenerWithSceneGraphPriority(listener, self.layout)
end

function PageCenterView:addEventListener(func)
	self._eventCallback = func
end

function PageCenterView:onTouchBegan(touch, event)
	local hitted = false
	if self:isVisible() and self:isEnabled() then
		local touchBeganPos = touch:getLocation()
		if self.layout:hitTest(touchBeganPos) then
			hitted = true
		end
	end
	print('onTouchBegan', hitted)
	return hitted
end

function PageCenterView:onTouchMoved(touch, event)
	-- print('PageCenterView:onTouchMoved')
	self:handleMoveLogic(touch)
end

function PageCenterView:onTouchEnded()
	-- print('PageCenterView:onTouchEnded')
	self:handleReleaseLogic(touch)
end

function PageCenterView:onTouchCancelled()
	-- print('PageCenterView:onTouchCancelled')
	self:handleReleaseLogic(touch)
end

function PageCenterView:handleMoveLogic(touch)
	local touchPoint = touch:getLocation()
	local preTouchPoint = touch:getPreviousLocation()
	local offset = {
		x = touchPoint.x - preTouchPoint.x,
		y = touchPoint.y - preTouchPoint.y,
	}
	if self._direction == PageCenterView.Direction.VERTICAL then
		offset.x = 0
		if offset.y > 0 then
			self._touchMoveDirection = PageCenterView.TouchDirection.UP
		elseif offset.y < 0 then
			self._touchMoveDirection = PageCenterView.TouchDirection.DOWN
		end
	else
	end

	self:scrollPages(offset)
end

function PageCenterView:handleReleaseLogic(touch)
	if self:getPageCount() <= 0 then
		return
	end
	local curPage = self._pages[self._curPageIdx]

	if curPage then
		local curPagePos = cc.p(curPage:getPosition())
		local pageCount = self:getPageCount()

		local selfSize = self:getContentSize()

		local moveBoundary = 0
		local moevPages = 0

		if self._direction == PageCenterView.Direction.VERTICAL then
			moveBoundary = curPagePos.y - self._leftBoundary
			movePages = math.floor(moveBoundary / (selfSize.height / self._pageNumShowed))
		end

		self._curPageIdx = self._curPageIdx + movePages
		if self._curPageIdx < 1 then
			self._curPageIdx = 1
		end
		if self._curPageIdx > pageCount then
			self._curPageIdx = pageCount
		end

		curPage = self._pages[self._curPageIdx]
		if not curPage then
			return
		end

		curPagePos = cc.p(curPage:getPosition())
		print('curPage', self._curPageIdx, curPagePos.x, curPagePos.y)

		local scrollDistance = 0
		if self._direction == PageCenterView.Direction.VERTICAL then
			curPagePos.x = 0
			moveBoundary = curPagePos.y - self._leftBoundary
			scrollDistance = selfSize.height / self._pageNumShowed / 2.0
		end

		local boundary = scrollDistance

		if self._direction == PageCenterView.Direction.VERTICAL then
			if moveBoundary >= boundary then
				if self._curPageIdx >= pageCount then
					self:scrollPages(curPagePos)
				else
					self:scrollToPage(self._curPageIdx + 1)
				end
			elseif moveBoundary <= -boundary then
				if self._curPageIdx <= 1 then
					self:scrollPages(curPagePos)
				else
					self:scrollToPage(self._curPageIdx - 1)
				end
			else
				self:scrollToPage(self._curPageIdx)
			end
		end
	end
end

function PageCenterView:update(dt)
	if self._isAutoScrolling then
		self:autoScroll(dt)
	end
end

function PageCenterView:autoScroll(dt)
	-- print('PageCenterView:autoScroll')
	local step = self._autoScrollSpeed * dt
	local sign = 1
	if self._autoScrollDirection == PageCenterView.AutoScrollDirection.UP then
		if self._autoScrollDistance + step >= 0 then
			step = -self._autoScrollDistance
			self._isAutoScrolling = false
			self._autoScrollDistance = 0
		else
			self._autoScrollDistance = self._autoScrollDistance + step
		end
		sign = -1
	elseif self._autoScrollDirection == PageCenterView.AutoScrollDirection.DOWN then
		if self._autoScrollDistance - step <= 0 then
			step = self._autoScrollDistance
			self._autoScrollDistance = 0
			self._isAutoScrolling = false
		else
			self._autoScrollDistance = self._autoScrollDistance - step
		end
	end
	if self._direction == PageCenterView.Direction.VERTICAL then
		self:scrollPages(cc.p(0, step * sign))
	end

	if not self._isAutoScrolling then
		self:pageTurningEvent()
	end
end

function PageCenterView:pageTurningEvent()
	if self._eventCallback then
		self._eventCallback(self, PageCenterView.EventType.TURNING)
	end
end

function PageCenterView:scrollToPage(idx)
	print('PageCenterView:scrollToPage', idx, self._curPageIdx)
	if idx < 1 or idx > self:getPageCount() then
		return
	end

	self._curPageIdx = idx

	local curPage = self._pages[idx]

	local selfSize = self:getContentSize()
	if self._direction == PageCenterView.Direction.VERTICAL then
		local pageHeight = selfSize.height / self._pageNumShowed
		self._autoScrollDistance = self._leftBoundary - cc.p(curPage:getPosition()).y
		if self._autoScrollDistance > 0 then
			self._autoScrollDirection = PageCenterView.AutoScrollDirection.DOWN
		else
			self._autoScrollDirection = PageCenterView.AutoScrollDirection.UP
		end
	end

	self._autoScrollSpeed = math.abs(self._autoScrollDistance) / 0.2
	self._isAutoScrolling = true
end

function PageCenterView:scrollPages(touchOffset)
	if self:getPageCount() <= 0 then
		return false
	end

	if not self._leftBoundaryChild or not self._rightBoundaryChild then
		return false
	end

	local realOffset = cc.p(touchOffset.x, touchOffset.y)

	if self._touchMoveDirection == PageCenterView.TouchDirection.UP then
		if self._rightBoundaryChild:getBottomBoundary() + touchOffset.y >= self._leftBoundary then
			realOffset.y = self._leftBoundary - self._rightBoundaryChild:getBottomBoundary()
			realOffset.x = 0
			self:movePages(realOffset)
			return false
		end
	elseif self._touchMoveDirection == PageCenterView.TouchDirection.DOWN then
		if self._leftBoundaryChild:getTopBoundary() + touchOffset.y <= self._rightBoundary then
			realOffset.y = self._rightBoundary - self._leftBoundaryChild:getTopBoundary()
			realOffset.x = 0
			self:movePages(realOffset)
			return false
		end
	end

	self:movePages(realOffset)
	return true
end

function PageCenterView:movePages(offset)
	for i, page in ipairs(self._pages) do
		local oldx, oldy = page:getPosition()
		page:setPosition(cc.p(oldx + offset.x, oldy + offset.y))
	end
end

function PageCenterView:getCurPageIndex()
	return self._curPageIdx
end

function PageCenterView:addPage(page)
	-- print('PageCenterView:addPage', page)
	page:setTouchEnabled(false)

	if not page or TableUtils.inTable(self._pages, page) then
		return
	end

	self:addChild(page)

	table.insert(self._pages, page)

	if self._curPageIdx == -1 then
		self._curPageIdx = 1
	end
	self._doLayoutDirty = true
end

function PageCenterView:setShowedNum(val)
	self._pageNumShowed = val
end

function PageCenterView:setMarkWidget(widget)
	-- self.layout:addChild(widget)
	self:addChild(widget)
	widget:setPositionType(ccui.PositionType.percent)
	widget:setPositionPercent(cc.p(0.5, 0.5))
	widget:setTouchEnabled(false)
end

function PageCenterView:setPosition(pos)
	self.layout:setPosition(pos)
end

function PageCenterView:getContentSize()
	return self.layout:getContentSize()
end

function PageCenterView:setContentSize(size)
	self.layout:setContentSize(size)

	self:onSizeChanged()
end

function PageCenterView:onSizeChanged()
	local selfSize = self:getContentSize()
	if self._direction == PageCenterView.Direction.VERTICAL then
		local pageHeight = selfSize.height / self._pageNumShowed
		self._leftBoundary = math.floor((self._pageNumShowed / 2)) * pageHeight
		self._rightBoundary = self._leftBoundary + pageHeight

		print('selfsize', selfSize.width, selfSize.height, self._leftBoundary, self._rightBoundary, self._pageNumShowed)
	else
	end

	self._doLayoutDirty = true
end

function PageCenterView:doLayout()
	if not self._doLayoutDirty then
		return
	end

	self:updateAllPagesPosition()
	self:updateAllPagesSize()
	self:updateBoundaryPages()

	self._doLayoutDirty = false
end

function PageCenterView:getPageCount()
	return TableUtils.size(self._pages)
end

function PageCenterView:updateAllPagesPosition()
	local pageCount = self:getPageCount()

	if pageCount <= 0 then
		self._curPageIdx = -1
		return
	end

	if self._curPageIdx >= pageCount then
		self._curPageIdx = pageCount
	end

	self._isAutoScrolling = false

	local selfSize = self:getContentSize()
	for i = 1, pageCount do
		local page = self._pages[i]
		local newPos

		if self._direction == PageCenterView.Direction.VERTICAL then
			local pageHeight = selfSize.height / self._pageNumShowed
			newPos = cc.p(0, self._leftBoundary + (i - self._curPageIdx) * pageHeight * -1)
		else
		end
		page:setPosition(newPos)
		-- print('page pos', i, newPos.x, newPos.y)
	end
end

function PageCenterView:updateAllPagesSize()
	local selfSize = self:getContentSize()
	local pageSize = cc.size(selfSize.width, selfSize.height)

	if self._direction == PageCenterView.Direction.VERTICAL then
		pageSize.height = pageSize.height / self._pageNumShowed
	else
	end

	for i, v in ipairs(self._pages) do
		v:setContentSize(pageSize)
	end
end

function PageCenterView:updateBoundaryPages()
	if TableUtils.size(self._pages) <= 0 then
		self._leftBoundaryChild = nil
		self._rightBoundaryChild = nil
		return
	end

	self._leftBoundaryChild = self._pages[1]
	self._rightBoundaryChild = self._pages[TableUtils.size(self._pages)]
end

function PageCenterView:isVisible()
	local function isVisible(node)
		if node then
			if node:isVisible() then
				local parent = node:getParent()
				return isVisible(parent)
			else
				return false
			end
		else
			return true
		end
	end
	return isVisible(self.layout)
end

function PageCenterView:isEnabled()
	return self.layout:isEnabled()
end

function PageCenterView:addChild(child)
	self.layout:addChild(child)
end

function PageCenterView:setLocalZOrder(val)
	self.layout:setLocalZOrder(val)
end

function PageCenterView:setBackGroundColor(val)
	self.layout:setBackGroundColor(val)
end

function PageCenterView:setBackGroundImage(val)
	self.layout:setBackGroundImage(val)
end

function PageCenterView:getWidget()
	return self.layout
end

return PageCenterView
