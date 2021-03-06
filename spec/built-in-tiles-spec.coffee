Grim = require 'grim'
fs = require 'fs-plus'
path = require 'path'
os = require 'os'

describe "Built-in Status Bar Tiles", ->
  [statusBar, workspaceElement, dummyView] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    dummyView = document.createElement("div")
    statusBar = null

    waitsForPromise ->
      atom.packages.activatePackage('status-bar')

    runs ->
      statusBar = workspaceElement.querySelector("status-bar")

  describe "the file info, cursor and selection tiles", ->
    [editor, buffer, fileInfo, cursorPosition, selectionCount] = []

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.js')

      runs ->
        [launchMode, fileInfo, cursorPosition, selectionCount] =
          statusBar.getLeftTiles().map (tile) -> tile.getItem()
        editor = atom.workspace.getActiveTextEditor()
        buffer = editor.getBuffer()

    describe "when associated with an unsaved buffer", ->
      it "displays 'untitled' instead of the buffer's path, but still displays the buffer position", ->
        waitsForPromise ->
          atom.workspace.open()

        runs ->
          expect(fileInfo.currentPath.textContent).toBe 'untitled'
          expect(cursorPosition.textContent).toBe '1,1'
          expect(selectionCount).toBeHidden()

    describe "when the associated editor's path changes", ->
      it "updates the path in the status bar", ->
        waitsForPromise ->
          atom.workspace.open('sample.txt')

        runs ->
          expect(fileInfo.currentPath.textContent).toBe 'sample.txt'

    describe "when the associated editor's buffer's content changes", ->
      it "enables the buffer modified indicator", ->
        expect(fileInfo.bufferModified.textContent).toBe ''
        editor.insertText("\n")
        advanceClock(buffer.stoppedChangingDelay)
        expect(fileInfo.bufferModified.textContent).toBe '*'
        editor.backspace()

    describe "when the buffer content has changed from the content on disk", ->
      it "disables the buffer modified indicator on save", ->
        filePath = path.join(os.tmpdir(), "atom-whitespace.txt")
        fs.writeFileSync(filePath, "")

        waitsForPromise ->
          atom.workspace.open(filePath)

        runs ->
          editor = atom.workspace.getActiveTextEditor()
          expect(fileInfo.bufferModified.textContent).toBe ''
          editor.insertText("\n")
          advanceClock(buffer.stoppedChangingDelay)
          expect(fileInfo.bufferModified.textContent).toBe '*'
          editor.getBuffer().save()
          expect(fileInfo.bufferModified.textContent).toBe ''

      it "disables the buffer modified indicator if the content matches again", ->
        expect(fileInfo.bufferModified.textContent).toBe ''
        editor.insertText("\n")
        advanceClock(buffer.stoppedChangingDelay)
        expect(fileInfo.bufferModified.textContent).toBe '*'
        editor.backspace()
        advanceClock(buffer.stoppedChangingDelay)
        expect(fileInfo.bufferModified.textContent).toBe ''

      it "disables the buffer modified indicator when the change is undone", ->
        expect(fileInfo.bufferModified.textContent).toBe ''
        editor.insertText("\n")
        advanceClock(buffer.stoppedChangingDelay)
        expect(fileInfo.bufferModified.textContent).toBe '*'
        editor.undo()
        advanceClock(buffer.stoppedChangingDelay)
        expect(fileInfo.bufferModified.textContent).toBe ''

    describe "when the buffer changes", ->
      it "updates the buffer modified indicator for the new buffer", ->
        expect(fileInfo.bufferModified.textContent).toBe ''

        waitsForPromise ->
          atom.workspace.open('sample.txt')

        runs ->
          editor = atom.workspace.getActiveTextEditor()
          editor.insertText("\n")
          advanceClock(buffer.stoppedChangingDelay)
          expect(fileInfo.bufferModified.textContent).toBe '*'

      it "doesn't update the buffer modified indicator for the old buffer", ->
        oldBuffer = editor.getBuffer()
        expect(fileInfo.bufferModified.textContent).toBe ''

        waitsForPromise ->
          atom.workspace.open('sample.txt')

        runs ->
          oldBuffer.setText("new text")
          advanceClock(buffer.stoppedChangingDelay)
          expect(fileInfo.bufferModified.textContent).toBe ''

    describe "when the associated editor's cursor position changes", ->
      it "updates the cursor position in the status bar", ->
        jasmine.attachToDOM(workspaceElement)
        editor.setCursorScreenPosition([1, 2])
        expect(cursorPosition.textContent).toBe '2,3'

    describe "when the associated editor's selection changes", ->
      it "updates the selection count in the status bar", ->
        jasmine.attachToDOM(workspaceElement)

        editor.setSelectedBufferRange([[0, 0], [0, 2]])
        expect(selectionCount.textContent).toBe '(2)'

    describe "when the active pane item does not implement getCursorBufferPosition()", ->
      it "hides the cursor position view", ->
        jasmine.attachToDOM(workspaceElement)
        atom.workspace.getActivePane().activateItem(dummyView)
        expect(cursorPosition).toBeHidden()

    describe "when the active pane item implements getTitle() but not getPath()", ->
      it "displays the title", ->
        jasmine.attachToDOM(workspaceElement)
        dummyView.getTitle = => 'View Title'
        atom.workspace.getActivePane().activateItem(dummyView)
        expect(fileInfo.currentPath.textContent).toBe 'View Title'
        expect(fileInfo.currentPath).toBeVisible()

    describe "when the active pane item neither getTitle() nor getPath()", ->
      it "hides the path view", ->
        jasmine.attachToDOM(workspaceElement)
        atom.workspace.getActivePane().activateItem(dummyView)
        expect(fileInfo.currentPath).toBeHidden()

    describe "when the active pane item's title changes", ->
      it "updates the path view with the new title", ->
        jasmine.attachToDOM(workspaceElement)
        callbacks = []
        dummyView.onDidChangeTitle = (fn) ->
          callbacks.push(fn)
          {dispose: ->}
        dummyView.getTitle = -> 'View Title'
        atom.workspace.getActivePane().activateItem(dummyView)
        expect(fileInfo.currentPath.textContent).toBe 'View Title'
        dummyView.getTitle = -> 'New Title'
        callback() for callback in callbacks
        expect(fileInfo.currentPath.textContent).toBe 'New Title'

  describe "the git tile", ->
    gitView = null

    beforeEach ->
      [gitView] = statusBar.getRightTiles().map (tile) -> tile.getItem()

    describe "the git branch label", ->
      beforeEach ->
        fs.removeSync(path.join(os.tmpdir(), '.git'))
        jasmine.attachToDOM(workspaceElement)

      it "displays the current branch for files in repositories", ->
        atom.project.setPaths([atom.project.getDirectories()[0].resolve('git/master.git')])

        waitsForPromise ->
          atom.workspace.open('HEAD')

        runs ->
          currentBranch = atom.project.getRepositories()[0].getShortHead()
          expect(gitView.branchArea).toBeVisible()
          expect(gitView.branchLabel.textContent).toBe currentBranch

          atom.workspace.getActivePane().destroyItems()
          expect(gitView.branchArea).toBeVisible()
          expect(gitView.branchLabel.textContent).toBe currentBranch

        atom.workspace.getActivePane().activateItem(dummyView)
        expect(gitView.branchArea).not.toBeVisible()

      it "doesn't display the current branch for a file not in a repository", ->
        atom.project.setPaths([os.tmpdir()])

        waitsForPromise ->
          atom.workspace.open(path.join(os.tmpdir(), 'temp.txt'))

        runs ->
          expect(gitView.branchArea).toBeHidden()

      it "doesn't display the current branch for a file outside the current project", ->
        waitsForPromise ->
          atom.workspace.open(path.join(os.tmpdir(), 'atom-specs', 'not-in-project.txt'))

        runs ->
          expect(gitView.branchArea).toBeHidden()

    describe "the git status label", ->
      [repo, filePath, originalPathText, newPath, ignorePath, ignoredPath, projectPath] = []

      beforeEach ->
        projectPath = atom.project.getDirectories()[0].resolve('git/working-dir')
        fs.moveSync(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
        atom.project.setPaths([projectPath])
        filePath = atom.project.getDirectories()[0].resolve('a.txt')
        newPath = atom.project.getDirectories()[0].resolve('new.txt')
        fs.writeFileSync(newPath, "I'm new here")
        ignorePath = path.join(projectPath, '.gitignore')
        fs.writeFileSync(ignorePath, 'ignored.txt')
        ignoredPath = path.join(projectPath, 'ignored.txt')
        fs.writeFileSync(ignoredPath, '')
        atom.project.getRepositories()[0].getPathStatus(filePath)
        atom.project.getRepositories()[0].getPathStatus(newPath)
        originalPathText = fs.readFileSync(filePath, 'utf8')
        jasmine.attachToDOM(workspaceElement)

      afterEach ->
        fs.writeFileSync(filePath, originalPathText)
        fs.removeSync(newPath)
        fs.removeSync(ignorePath)
        fs.removeSync(ignoredPath)
        fs.moveSync(path.join(projectPath, '.git'), path.join(projectPath, 'git.git'))

      it "displays the modified icon for a changed file", ->
        fs.writeFileSync(filePath, "i've changed for the worse")
        atom.project.getRepositories()[0].getPathStatus(filePath)

        waitsForPromise ->
          atom.workspace.open(filePath)

        runs ->
          expect(gitView.gitStatusIcon).toHaveClass('icon-diff-modified')

      it "doesn't display the modified icon for an unchanged file", ->
        waitsForPromise ->
          atom.workspace.open(filePath)

        runs ->
          expect(gitView.gitStatusIcon).toHaveText('')

      it "displays the new icon for a new file", ->
        waitsForPromise ->
          atom.workspace.open(newPath)

        runs ->
          expect(gitView.gitStatusIcon).toHaveClass('icon-diff-added')

      it "displays the ignored icon for an ignored file", ->
        waitsForPromise ->
          atom.workspace.open(ignoredPath)

        runs ->
          expect(gitView.gitStatusIcon).toHaveClass('icon-diff-ignored')

      it "updates when a status-changed event occurs", ->
        fs.writeFileSync(filePath, "i've changed for the worse")
        atom.project.getRepositories()[0].getPathStatus(filePath)

        waitsForPromise ->
          atom.workspace.open(filePath)

        runs ->
          expect(gitView.gitStatusIcon).toHaveClass('icon-diff-modified')
          fs.writeFileSync(filePath, originalPathText)
          atom.project.getRepositories()[0].getPathStatus(filePath)
          expect(gitView.gitStatusIcon).not.toHaveClass('icon-diff-modified')

      it "displays the diff stat for modified files", ->
        fs.writeFileSync(filePath, "i've changed for the worse")
        atom.project.getRepositories()[0].getPathStatus(filePath)

        waitsForPromise ->
          atom.workspace.open(filePath)

        runs ->
          expect(gitView.gitStatusIcon).toHaveText('+1')

      it "displays the diff stat for new files", ->
        waitsForPromise ->
          atom.workspace.open(newPath)

        runs ->
          expect(gitView.gitStatusIcon).toHaveText('+1')

      it "does not display for files not in the current project", ->
        waitsForPromise ->
          atom.workspace.open('/tmp/atom-specs/not-in-project.txt')

        runs ->
          expect(gitView.gitStatusIcon).toBeHidden()
