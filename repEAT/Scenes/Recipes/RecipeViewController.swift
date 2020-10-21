//
//  RecipeViewController.swift
//  repEAT
//
//  Created by Witt, Robert on 04.10.20.
//

import UIKit
import CoreData
import AVFoundation

class RecipeViewController: UITableViewController {
    
    weak var delegate: RecipeViewControllerDelegate?
    
    var recipe: Recipe {
        get {
            return recipeController.recipe
        }
        set {
            recipeController = RecipeController(with: newValue)
        }
    }
    
    var isCreatingRecipe = false
    
    private var recipeController: RecipeController!
    
    private var cancelButtonItem: UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .cancel,
                               target: self,
                               action: #selector(cancelItemPressed))
    }
    
    private var recipeImageView: EditableImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBar()
        setupRecipeImageView()
        updateTableHeaderView()
        registerTableViewCells()
    }
    
    private func setupNavBar() {
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    private func setupRecipeImageView() {
        recipeImageView = EditableImageView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 200))
        recipeImageView.changeImagePressedButtonHandler = { () -> Void in
            self.showChangeRecipeImageOptions()
        }
    }
    
    private func showChangeRecipeImageOptions() {
        let actionSheet = UIAlertController(title: NSLocalizedString("alertTitleChangeImage", comment: ""),
                                            message: nil,
                                            preferredStyle: .actionSheet)
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            actionSheet.addAction(UIAlertAction(title: NSLocalizedString("actionPhotoLibrary", comment: ""), style: .default, handler: { (_) in
                self.showPhotoLibrary()
            }))
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actionSheet.addAction(UIAlertAction(title: NSLocalizedString("actionCamera", comment: ""), style: .default, handler: { (_) in
                self.showCamera()
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("actionDelete", comment: ""), style: .destructive, handler: { (_) in
            self.deleteRecipeImage()
        }))
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("actionCancel", comment: ""), style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func showPhotoLibrary() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.allowsEditing = true
        present(imagePickerController, animated: true)
    }
    
    private func showCamera() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .denied:
            showAlertToEnableCamera()
        case .notDetermined:
            requestCameraAccess()
        default:
            showCameraIfAccessGranted()
        }
    }
    
    private func showAlertToEnableCamera() {
        let alert = UIAlertController(title: NSLocalizedString("alertTitleCameraUnavailable", comment: ""),
                                      message: NSLocalizedString("alertMessageCameraUnavailable", comment: ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("actionOK", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("actionSettings", comment: ""), style: .default, handler: { (_) in
            self.openSettings()
        }))
        
        present(alert, animated: true)
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { (granted) in
            if granted {
                DispatchQueue.main.async {
                    self.showCameraIfAccessGranted()
                }
            }
        }
    }
    
    private func showCameraIfAccessGranted() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .camera
        imagePickerController.allowsEditing = true
        present(imagePickerController, animated: true)
    }
    
    private func deleteRecipeImage() {
        setRecipeImage(nil)
    }
    
    private func setRecipeImage(_ image: UIImage?) {
        recipe.image = image
        updateTableHeaderView()
    }
    
    private func updateTableHeaderView() {
        recipeImageView.image = recipe.image
        recipeImageView.isEditing = isEditing
        tableView.tableHeaderView = isEditing || recipe.image != nil ? recipeImageView : nil
    }
    
    private func registerTableViewCells() {
        EditableTableViewCell.register(in: tableView, reuseIdentifier: EditableTableViewCell.reuseIdentifier)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if !editing {
            updateRecipe()
        }
        
        recipeController.isEditing = editing
        navigationItem.leftBarButtonItem = editing ? cancelButtonItem : nil
        updateTableHeaderView()
        tableView.reloadData()
    }
    
    private func updateRecipe() {
        if isCancellationRequested {
            cancelEditing()
        } else {
            saveRecipe()
        }
    }
    
    private func cancelEditing() {
        delegate?.recipeViewControllerDidCancel(self)
        isCancellationRequested = false
    }
    
    private func saveRecipe() {
        delegate?.recipeViewController(self, didEndEditingRecipe: recipe)
        isCreatingRecipe = false
    }
    
    @objc private func cancelItemPressed() {
        isCancellationRequested = true
        setEditing(false, animated: true)
    }
    
    private var isCancellationRequested = false

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "IngredientSegue":
            prepareIngredientViewController(for: segue, sender: sender)
        case "DirectionSegue":
            prepareDirectionViewController(for: segue, sender: sender)
        default:
            break
        }
    }
    
    private func prepareIngredientViewController(for segue: UIStoryboardSegue, sender: Any?) {
        guard let viewController = segue.destination as? IngredientViewController else {
            return
        }
        guard let indexPath = sender as? IndexPath else {
            return
        }
        
        let ingredient = recipeController.ingredient(at: indexPath.row) ?? recipe.createIngredient()
        viewController.ingredient = ingredient
        viewController.delegate = self
    }
    
    private func prepareDirectionViewController(for segue: UIStoryboardSegue, sender: Any?) {
        guard let viewController = segue.destination as? DirectionViewController else {
            return
        }
        guard let indexPath = sender as? IndexPath else {
            return
        }
        
        let direction = recipeController.direction(at: indexPath.row) ?? recipe.createDirection()
        viewController.direction = direction
        viewController.maxSteps = recipe.directions?.count ?? 0 + 1
        viewController.delegate = self
    }

    // MARK: Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return recipeController.numberOfSections
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return recipeController.headerTitle(of: section)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recipeController.numberOfObjects(in: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch RecipeController.Section(rawValue: indexPath.section) {
        case .details:
            return detailsCell(forRowAt: indexPath)
        case .ingredients:
            return ingredientCell(forRowAt: indexPath)
        case.directions:
            return directionCell(forRowAt: indexPath)
        default:
            return UITableViewCell()
        }
    }
    
    private func detailsCell(forRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: EditableTableViewCell.reuseIdentifier, for: indexPath) as! EditableTableViewCell
        // swiftlint:enable force_cast
        cell.textField.text = recipe.name
        cell.textField.placeholder = NSLocalizedString("placeholderRecipeName", comment: "")
        cell.textChangedHandler = { (recipeName) in
            self.recipe.name = recipeName
        }
        
        return cell
    }
    
    private func ingredientCell(forRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let ingredient = recipeController.ingredient(at: indexPath.row) else {
            return addCell(forRowAt: indexPath)
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "IngredientCell", for: indexPath)
        cell.textLabel?.text = ingredient.formattedQuantityWithUnit
        cell.detailTextLabel?.text = ingredient.food?.name
        cell.selectionStyle = isEditing ? .default : .none
        
        return cell
    }
    
    private func directionCell(forRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let direction = recipeController.direction(at: indexPath.row) else {
            return addCell(forRowAt: indexPath)
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "DirectionCell", for: indexPath)
        cell.textLabel?.text = direction.depiction
        cell.selectionStyle = isEditing ? .default : .none
        
        return cell
    }
    
    private func addCell(forRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "AddCell", for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .insert:
            insertRow(at: indexPath)
        case .delete:
            deleteRow(at: indexPath)
        default:
            break
        }
    }
    
    private func insertRow(at indexPath: IndexPath) {
        // Inserting rows behaves the same as selecting rows
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    private func deleteRow(at indexPath: IndexPath) {
        recipeController.deleteObject(at: indexPath)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return recipeController.canMoveObject(at: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        return recipeController.targetIndexPathForMoveFromObject(at: sourceIndexPath, to: proposedDestinationIndexPath)
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        recipeController.moveObject(at: sourceIndexPath, to: destinationIndexPath)
        tableView.moveRow(at: sourceIndexPath, to: destinationIndexPath)
    }
    
    // MARK: Table View Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard isEditing else {
            return
        }
        
        switch RecipeController.Section(rawValue: indexPath.section) {
        case .ingredients:
            performSegue(withIdentifier: "IngredientSegue", sender: indexPath)
        case .directions:
            performSegue(withIdentifier: "DirectionSegue", sender: indexPath)
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if recipeController.canDeleteObject(at: indexPath) {
            return .delete
        } else if recipeController.canInsertObject(at: indexPath) {
            return .insert
        } else {
            return .none
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section != RecipeController.Section.details.rawValue
    }
    
}

// MARK: - Image Picker Controller Delegate

extension RecipeViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let selectedImage = info[.editedImage] as? UIImage else {
            return
        }
        setRecipeImage(selectedImage)
    }
    
}

// MARK: - Ingredient View Controller Delegate

extension RecipeViewController: IngredientViewControllerDelegate {
    
    func ingredientViewController(_ viewController: IngredientViewController, didEndEditing ingredient: Ingredient) {
        let indexSet = IndexSet(integer: RecipeController.Section.ingredients.rawValue)
        tableView.reloadSections(indexSet, with: .none)
    }
    
    func ingredientViewControllerNewIngredient(_ viewController: IngredientViewController) -> Ingredient {
        return recipe.createIngredient()
    }
    
}

// MARK: - Direction View Controller Delegate

extension RecipeViewController: DirectionViewControllerDelegate {
    
    func directionViewController(_ viewController: DirectionViewController, didEndEditing direction: Direction) {
        let indexSet = IndexSet(integer: RecipeController.Section.directions.rawValue)
        tableView.reloadSections(indexSet, with: .none)
    }
    
    func directionViewController(_ viewController: DirectionViewController, directionToAddAfter direction: Direction) -> Direction {
        return recipe.createDirection()
    }
    
}

// MARK: - Recipe View Controller

protocol RecipeViewControllerDelegate: class {
    
    func recipeViewControllerDidCancel(_ viewController: RecipeViewController)
    
    func recipeViewController(_ viewController: RecipeViewController, didEndEditingRecipe recipe: Recipe)
    
}

extension RecipeViewControllerDelegate {
    
    func recipeViewControllerDidCancel(_ viewController: RecipeViewController) {}
    
    func recipeViewController(_ viewController: RecipeViewController, didEndEditingRecipe recipe: Recipe) {}
    
}
